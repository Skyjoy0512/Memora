import cron from "node-cron";
import type { MeetingJob } from "./api/meetings.js";
import { jobs } from "./api/meetings.js";
import { googleMeetJoin } from "./platforms/google-meet.js";
import { zoomJoin } from "./platforms/zoom.js";
import { teamsJoin } from "./platforms/teams.js";
import { startRecording, stopRecording } from "./audio/recorder.js";
import { uploadAudio } from "./audio/uploader.js";
import {
  notifyMeetingCompleted,
  notifyMeetingFailed,
} from "./api/webhooks.js";

/** Max concurrent meeting executions */
const MAX_CONCURRENT_MEETINGS = 5;

export class SchedulerService {
  private cronJob: cron.ScheduledTask | null = null;
  private activeJobs = new Set<string>();

  async start() {
    // Check every 30 seconds
    this.cronJob = cron.schedule("*/30 * * * * *", async () => {
      await this.processDueMeetings();
    });
    console.log("[Scheduler] Started — checking every 30s");
  }

  async stop() {
    if (this.cronJob) {
      this.cronJob.stop();
      this.cronJob = null;
    }
    console.log("[Scheduler] Stopped");
  }

  private async processDueMeetings() {
    if (jobs.size === 0) return;

    const now = new Date();
    const dueJobs: MeetingJob[] = [];

    for (const [, job] of jobs) {
      if (job.status !== "pending") continue;
      if (this.activeJobs.has(job.meetingID)) continue;

      const scheduledTime = new Date(job.scheduledTime);
      const windowStart = new Date(scheduledTime.getTime() - 60_000);
      const windowEnd = new Date(scheduledTime.getTime() + job.durationMinutes * 60_000);

      if (now >= windowStart && now <= windowEnd) {
        dueJobs.push(job);
      }
    }

    if (dueJobs.length === 0) return;

    // ── Parallel execution with concurrency limit ─────────────────
    const available = MAX_CONCURRENT_MEETINGS - this.activeJobs.size;
    const toStart = dueJobs.slice(0, Math.max(1, available));

    console.log(
      `[Scheduler] Starting ${toStart.length} meeting(s) (${this.activeJobs.size} active, ${dueJobs.length} due)`
    );

    // Fire all eligible jobs in parallel
    await Promise.allSettled(
      toStart.map((job) => this.executeJob(job))
    );
  }

  private async executeJob(job: MeetingJob) {
    this.activeJobs.add(job.meetingID);

    try {
      // ── Stage 1: Join ──────────────────────────────────────────
      job.status = "joined";
      console.log(`[Scheduler] Joining: ${job.meetingTitle} (${job.platform})`);

      try {
        await joinPlatform(job);
      } catch (err: any) {
        console.warn(
          `[Scheduler] Platform join warning for ${job.platform}: ${err.message}`
        );
      }

      // ── Stage 2: Record ────────────────────────────────────────
      job.status = "recording";
      console.log(
        `[Scheduler] Recording: ${job.meetingTitle} (${job.durationMinutes} min)`
      );

      // Start recording asynchronously
      await startRecording(job.meetingID, job.durationMinutes);

      // Wait for the meeting duration so the recording covers the full slot.
      // In production this is driven by platform events (meeting ended callback).
      await new Promise<void>((resolve) =>
        setTimeout(resolve, job.durationMinutes * 60_000)
      );

      const filePath = await stopRecording(job.meetingID);
      console.log(`[Scheduler] Recording finished: ${filePath}`);

      // ── Stage 3: Upload ────────────────────────────────────────
      const audioURL = await uploadAudio(filePath, job.meetingID);

      // ── Stage 4: Complete ──────────────────────────────────────
      job.status = "completed";
      job.audioURL = audioURL;
      console.log(`[Scheduler] Completed: ${job.meetingTitle} -> ${audioURL}`);

      // ── Stage 5: Notify ────────────────────────────────────────
      await notifyMeetingCompleted(job, audioURL);
    } catch (err: any) {
      job.status = "failed";
      job.error = err.message;
      console.error(`[Scheduler] Failed: ${job.meetingTitle} — ${err.message}`);

      try {
        await notifyMeetingFailed(job, err.message);
      } catch (notifyErr: any) {
        console.error(
          `[Scheduler] Webhook error for ${job.meetingID}: ${notifyErr.message}`
        );
      }
    } finally {
      this.activeJobs.delete(job.meetingID);
    }
  }
}

async function joinPlatform(job: MeetingJob): Promise<void> {
  switch (job.platform) {
    case "google_meet":
      await googleMeetJoin(job);
      break;
    case "zoom":
      await zoomJoin(job);
      break;
    case "teams":
      await teamsJoin(job);
      break;
    default:
      throw new Error(`Unsupported platform: ${job.platform}`);
  }
}
