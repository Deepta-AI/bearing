import { type FastifyPluginCallbackZod } from "fastify-type-provider-zod";
import { z } from "zod";

import { ServiceUnavailableError } from "../errors.js";

/** ReadinessCheck rejects when a dependency the service needs is unreachable. */
export type ReadinessCheck = () => Promise<void>;

export interface HealthOptions {
  version: string;
  /** Absent when the service has no database configured. */
  readiness?: ReadinessCheck | undefined;
}

const healthSchema = z.object({ status: z.literal("ok"), version: z.string() });
const readySchema = z.object({
  status: z.literal("ok"),
  checks: z.record(z.string(), z.enum(["ok", "not configured"])),
});

/** healthRoutes serves liveness (/healthz) and readiness (/readyz). */
export const healthRoutes: FastifyPluginCallbackZod<HealthOptions> = (app, options, done) => {
  app.get("/healthz", { schema: { response: { 200: healthSchema } }, logLevel: "silent" }, () => ({
    status: "ok" as const,
    version: options.version,
  }));

  app.get(
    "/readyz",
    { schema: { response: { 200: readySchema } }, logLevel: "silent" },
    async (request) => {
      if (!options.readiness) {
        return { status: "ok" as const, checks: { database: "not configured" as const } };
      }
      try {
        await options.readiness();
      } catch (error) {
        request.log.warn({ err: error, check: "database" }, "readiness failed");
        throw new ServiceUnavailableError("database unreachable", {
          details: { database: "failed" },
          cause: error,
        });
      }
      return { status: "ok" as const, checks: { database: "ok" as const } };
    },
  );
  done();
};
