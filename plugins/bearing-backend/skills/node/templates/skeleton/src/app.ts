import { randomUUID } from "node:crypto";

import Fastify, {
  type FastifyBaseLogger,
  type FastifyInstance,
  LogController,
  type RawReplyDefaultExpression,
  type RawRequestDefaultExpression,
  type RawServerDefault,
} from "fastify";
import {
  serializerCompiler,
  validatorCompiler,
  type ZodTypeProvider,
} from "fastify-type-provider-zod";
import type pg from "pg";

import { type Config } from "./config.js";
import { createDb, pingDatabase, type Db } from "./db/client.js";
import { registerErrorHandling } from "./errors.js";
import { loggerOptions } from "./logger.js";
import { createMetrics, registerMetrics } from "./metrics.js";
import { healthRoutes, type ReadinessCheck } from "./routes/health.js";

declare module "fastify" {
  interface FastifyInstance {
    /** The Drizzle handle, or null when DATABASE_URL is not set. */
    db: Db | null;
  }
}

export interface AppDeps {
  config: Config;
  version: string;
  /** The pg pool; absent means no database. It is ended when the app closes. */
  pool?: pg.Pool | undefined;
  /** Overrides the pool ping; tests inject a failing check. */
  readiness?: ReadinessCheck | undefined;
}

/** App is the Fastify instance with the Zod type provider, so every route schema infers. */
export type App = FastifyInstance<
  RawServerDefault,
  RawRequestDefaultExpression,
  RawReplyDefaultExpression,
  FastifyBaseLogger,
  ZodTypeProvider
>;

/**
 * buildApp assembles the Fastify instance: logger, request id, error
 * mapping, metrics, database handle and routes. No listening, no signals;
 * server.ts owns the process. Tests build one per case with `inject`.
 */
export function buildApp({ config, version, pool, readiness }: AppDeps): App {
  const app = Fastify({
    logger: loggerOptions(config),
    requestIdHeader: "x-request-id",
    genReqId: () => randomUUID(),
    // Fastify's own two lines per request are off; onResponse below logs one.
    logController: new LogController({
      disableRequestLogging: true,
      requestIdLogLabel: "requestId",
    }),
    bodyLimit: 1_048_576,
    trustProxy: false,
  }).withTypeProvider<ZodTypeProvider>();

  app.setValidatorCompiler(validatorCompiler);
  app.setSerializerCompiler(serializerCompiler);

  app.addHook("onSend", (request, reply, _payload, done) => {
    reply.header("x-request-id", request.id);
    done();
  });
  // One line per request, with the request id bound by pino.
  app.addHook("onResponse", (request, reply, done) => {
    request.log.info(
      {
        method: request.method,
        url: request.url,
        route: request.routeOptions.url ?? "unmatched",
        status: reply.statusCode,
        durationMs: Math.round(reply.elapsedTime * 10) / 10,
      },
      "request",
    );
    done();
  });

  registerErrorHandling(app);
  registerMetrics(app, createMetrics());

  app.decorate("db", pool ? createDb(pool) : null);
  if (pool) {
    app.addHook("onClose", async () => {
      await pool.end();
    });
  }

  const check = readiness ?? (pool ? () => pingDatabase(pool) : undefined);
  void app.register(healthRoutes, { version, readiness: check });

  return app;
}
