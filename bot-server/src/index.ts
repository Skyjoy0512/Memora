import fastify from "fastify";
import { meetingRoutes } from "./api/meetings.js";
import { healthRoutes } from "./api/health.js";
import { webhookRoutes } from "./api/webhooks.js";
import { SchedulerService } from "./scheduler.js";

const PORT = parseInt(process.env.PORT || "3000", 10);
const API_KEY = process.env.API_KEY || "changeme";

async function main() {
  const server = fastify({
    logger: {
      transport: {
        target: "pino-pretty",
        options: { translateTime: "HH:MM:ss Z", ignore: "pid,hostname" },
      },
    },
  });

  // Auth check hook
  server.addHook("onRequest", async (request, reply) => {
    if (request.url === "/health") return;

    const auth = request.headers.authorization;
    if (!auth || auth !== `Bearer ${API_KEY}`) {
      reply.status(401).send({ error: "Unauthorized" });
    }
  });

  // Register routes
  await server.register(healthRoutes);
  await server.register(meetingRoutes);
  await server.register(webhookRoutes);

  // Start scheduler
  const scheduler = new SchedulerService();
  await scheduler.start();

  // Graceful shutdown
  const shutdown = async () => {
    server.log.info("Shutting down...");
    await scheduler.stop();
    await server.close();
    process.exit(0);
  };

  process.on("SIGTERM", shutdown);
  process.on("SIGINT", shutdown);

  // Start server
  try {
    await server.listen({ port: PORT, host: "0.0.0.0" });
    server.log.info(`Memora Bot Server listening on port ${PORT}`);
  } catch (err) {
    server.log.error(err);
    process.exit(1);
  }
}

main();
