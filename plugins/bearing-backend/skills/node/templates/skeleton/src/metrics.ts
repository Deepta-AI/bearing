import { collectDefaultMetrics, Histogram, Registry } from "prom-client";

import { type App } from "./app.js";

/** Metrics holds the registry and the one request histogram every service exports. */
export interface Metrics {
  registry: Registry;
  httpRequestDuration: Histogram<"method" | "route" | "status">;
}

/** createMetrics builds a fresh registry with the Node process defaults and the HTTP histogram. */
export function createMetrics(): Metrics {
  const registry = new Registry();
  collectDefaultMetrics({ register: registry });
  const httpRequestDuration = new Histogram({
    name: "http_request_duration_seconds",
    help: "HTTP request duration in seconds by method, route and status",
    labelNames: ["method", "route", "status"] as const,
    buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5],
    registers: [registry],
  });
  return { registry, httpRequestDuration };
}

/**
 * registerMetrics observes every response by its route pattern (never the
 * raw URL, which would explode the label set) and serves GET /metrics.
 */
export function registerMetrics(app: App, metrics: Metrics): void {
  app.addHook("onResponse", (request, reply, done) => {
    const route = request.routeOptions.url ?? "unmatched";
    if (route !== "/metrics") {
      metrics.httpRequestDuration.observe(
        { method: request.method, route, status: String(reply.statusCode) },
        reply.elapsedTime / 1000,
      );
    }
    done();
  });

  app.get("/metrics", { logLevel: "silent" }, async (_request, reply) => {
    const body = await metrics.registry.metrics();
    return reply.header("content-type", metrics.registry.contentType).send(body);
  });
}
