import { loadConfig } from "./config.js";
import { startTelemetry } from "./telemetry.js";

// Wiring only: config, tracing, pool, app, listen, signals. Everything
// testable lives in app.ts and below.
const config = loadConfig();
const sdk = startTelemetry({
  endpoint: config.OTEL_EXPORTER_OTLP_ENDPOINT,
  serviceName: config.SERVICE_NAME,
  version: config.SERVICE_VERSION,
});

// Imported after the SDK starts so its instrumentation sees http, pg and pino load.
const [{ buildApp }, { createPool }] = await Promise.all([
  import("./app.js"),
  import("./db/client.js"),
]);

const pool = config.DATABASE_URL ? createPool(config.DATABASE_URL, config.DB_POOL_MAX) : undefined;
const app = buildApp({ config, version: config.SERVICE_VERSION, pool });

let closing = false;
async function shutdown(reason: string): Promise<void> {
  if (closing) {
    return;
  }
  closing = true;
  app.log.info({ reason }, "shutting down");
  const timer = setTimeout(() => {
    app.log.error({ timeoutMs: config.SHUTDOWN_TIMEOUT_MS }, "shutdown timed out");
    process.exit(1);
  }, config.SHUTDOWN_TIMEOUT_MS);
  timer.unref();
  try {
    await app.close();
    await sdk?.shutdown();
    process.exit(0);
  } catch (error) {
    app.log.error({ err: error }, "shutdown failed");
    process.exit(1);
  }
}

process.on("SIGINT", () => void shutdown("SIGINT"));
process.on("SIGTERM", () => void shutdown("SIGTERM"));
process.on("unhandledRejection", (reason) => {
  app.log.fatal({ err: reason }, "unhandled rejection");
  void shutdown("unhandledRejection");
});

try {
  await app.listen({ port: config.PORT, host: config.HOST });
  app.log.info(
    { env: config.NODE_ENV, version: config.SERVICE_VERSION, tracing: sdk !== null },
    "started",
  );
} catch (error) {
  app.log.fatal({ err: error }, "listen failed");
  process.exit(1);
}
