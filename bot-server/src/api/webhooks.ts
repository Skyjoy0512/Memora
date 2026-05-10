import { FastifyPluginAsync } from "fastify";
import type { MeetingJob } from "./meetings.js";

// ---------------------------------------------------------------------------
// Standalone helpers (usable outside Fastify context)
// ---------------------------------------------------------------------------

/**
 * POST a JSON payload to a webhook URL.
 *
 * @returns `true` when the remote responds with a 2xx status.
 */
export async function sendWebhook(
  webhookURL: string,
  payload: Record<string, unknown>
): Promise<boolean> {
  try {
    const response = await fetch(webhookURL, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });

    if (response.ok) {
      console.log(`[Webhook] Delivered to ${webhookURL} (${response.status})`);
      return true;
    }

    console.warn(
      `[Webhook] Non-2xx from ${webhookURL}: ${response.status} ${response.statusText}`
    );
    return false;
  } catch (err: any) {
    console.error(`[Webhook] Failed to reach ${webhookURL}: ${err.message}`);
    return false;
  }
}

/**
 * Notify the iOS app that a meeting completed successfully.
 */
export async function notifyMeetingCompleted(
  meeting: MeetingJob,
  audioURL: string
): Promise<void> {
  if (!meeting.webhookURL) {
    console.log(`[Webhook] No webhookURL configured for meeting ${meeting.meetingID}, skipping notification`);
    return;
  }

  const payload = {
    event: "meeting.completed",
    meetingID: meeting.meetingID,
    meetingTitle: meeting.meetingTitle,
    platform: meeting.platform,
    audioURL,
    timestamp: new Date().toISOString(),
  };

  const ok = await sendWebhook(meeting.webhookURL, payload);
  if (!ok) {
    console.warn(
      `[Webhook] Failed to notify completion for meeting ${meeting.meetingID}`
    );
  }
}

/**
 * Notify the iOS app that a meeting failed.
 */
export async function notifyMeetingFailed(
  meeting: MeetingJob,
  error: string
): Promise<void> {
  if (!meeting.webhookURL) {
    console.log(`[Webhook] No webhookURL configured for meeting ${meeting.meetingID}, skipping notification`);
    return;
  }

  const payload = {
    event: "meeting.failed",
    meetingID: meeting.meetingID,
    meetingTitle: meeting.meetingTitle,
    platform: meeting.platform,
    error,
    timestamp: new Date().toISOString(),
  };

  const ok = await sendWebhook(meeting.webhookURL, payload);
  if (!ok) {
    console.warn(
      `[Webhook] Failed to notify failure for meeting ${meeting.meetingID}`
    );
  }
}

// ---------------------------------------------------------------------------
// Fastify plugin – exposes test routes under /webhooks/test
// ---------------------------------------------------------------------------

export const webhookRoutes: FastifyPluginAsync = async (server) => {
  /**
   * POST /webhooks/test
   *
   * Accepts a target URL + optional payload and fires a test webhook.
   * Useful for verifying connectivity from the bot server to the iOS app.
   */
  server.post("/webhooks/test", async (request, reply) => {
    const { url, payload } = request.body as {
      url: string;
      payload?: Record<string, unknown>;
    };

    if (!url) {
      reply.status(400).send({ error: "Missing `url` in request body" });
      return;
    }

    const testPayload = payload ?? {
      event: "test",
      message: "Hello from Memora Bot Server",
      timestamp: new Date().toISOString(),
    };

    const ok = await sendWebhook(url, testPayload);

    reply.status(ok ? 200 : 502).send({
      delivered: ok,
      url,
      timestamp: new Date().toISOString(),
    });
  });
};
