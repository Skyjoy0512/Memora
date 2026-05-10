import { Type } from "@sinclair/typebox";
import { TypeBoxTypeProvider } from "@fastify/type-provider-typebox";
import { FastifyPluginAsync } from "fastify";

export interface MeetingJob {
  meetingID: string;
  platform: string;
  meetingURL: string;
  meetingTitle: string;
  scheduledTime: string;
  durationMinutes: number;
  status: "pending" | "joined" | "recording" | "completed" | "failed";
  audioURL?: string;
  error?: string;
  webhookURL?: string;
  createdAt: string;
}

// In-memory store (replace with DB for production)
export const jobs = new Map<string, MeetingJob>();

const MeetingScheduleSchema = Type.Object({
  meetingID: Type.String(),
  platform: Type.String(),
  meetingURL: Type.String(),
  meetingTitle: Type.String(),
  scheduledTime: Type.String(),
  durationMinutes: Type.Number({ default: 60 }),
  webhookURL: Type.Optional(Type.String()),
});

const MeetingStatusSchema = Type.Object({
  jobID: Type.String(),
  status: Type.String(),
  audioURL: Type.Optional(Type.String()),
  transcript: Type.Optional(Type.String()),
  summary: Type.Optional(Type.String()),
  error: Type.Optional(Type.String()),
});

export const meetingRoutes: FastifyPluginAsync = async (server) => {
  const app = server.withTypeProvider<TypeBoxTypeProvider>();

  // Schedule a new meeting
  app.post(
    "/meetings",
    { schema: { body: MeetingScheduleSchema } },
    async (request, reply) => {
      const body = request.body;

      const job: MeetingJob = {
        meetingID: body.meetingID,
        platform: body.platform,
        meetingURL: body.meetingURL,
        meetingTitle: body.meetingTitle,
        scheduledTime: body.scheduledTime,
        durationMinutes: body.durationMinutes,
        status: "pending",
        webhookURL: body.webhookURL,
        createdAt: new Date().toISOString(),
      };

      jobs.set(body.meetingID, job);
      request.log.info(
        { meetingID: body.meetingID, platform: body.platform },
        "Meeting scheduled"
      );

      reply.status(201).send({
        jobID: body.meetingID,
        status: "pending",
        scheduledTime: body.scheduledTime,
      });
    }
  );

  // Get meeting status
  app.get("/meetings/:jobID", async (request, reply) => {
    const { jobID } = request.params as { jobID: string };
    const job = jobs.get(jobID);

    if (!job) {
      reply.status(404).send({ error: "Meeting not found" });
      return;
    }

    return {
      meetingID: job.meetingID,
      platform: job.platform,
      meetingURL: job.meetingURL,
      meetingTitle: job.meetingTitle,
      scheduledTime: job.scheduledTime,
      durationMinutes: job.durationMinutes,
      status: job.status,
      audioURL: job.audioURL,
      error: job.error,
      createdAt: job.createdAt,
    } satisfies MeetingJob;
  });

  // Cancel meeting
  app.delete("/meetings/:jobID", async (request, reply) => {
    const { jobID } = request.params as { jobID: string };
    const job = jobs.get(jobID);

    if (!job) {
      reply.status(404).send({ error: "Meeting not found" });
      return;
    }

    if (job.status === "recording" || job.status === "joined") {
      job.status = "failed";
      job.error = "Cancelled by user";
    } else {
      jobs.delete(jobID);
    }

    reply.status(200).send({ status: "cancelled" });
  });

  // List all meetings
  app.get("/meetings", async () => {
    return Array.from(jobs.values());
  });
};
