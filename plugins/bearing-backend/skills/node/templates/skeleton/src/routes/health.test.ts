import { afterEach, describe, expect, it } from "vitest";

import { buildApp, type App } from "../app.js";
import { loadConfig } from "../config.js";

const config = loadConfig({ NODE_ENV: "test", LOG_LEVEL: "silent" });
let app: App | undefined;

afterEach(async () => {
  await app?.close();
  app = undefined;
});

describe("GET /healthz", () => {
  it("reports the version", async () => {
    app = buildApp({ config, version: "1.2.3" });

    const response = await app.inject({ method: "GET", url: "/healthz" });

    expect(response.statusCode).toBe(200);
    expect(response.json()).toEqual({ status: "ok", version: "1.2.3" });
  });

  it("echoes an incoming request id", async () => {
    app = buildApp({ config, version: "test" });

    const response = await app.inject({
      method: "GET",
      url: "/healthz",
      headers: { "x-request-id": "abc-123" },
    });

    expect(response.headers["x-request-id"]).toBe("abc-123");
  });

  it("mints a request id when none is sent", async () => {
    app = buildApp({ config, version: "test" });

    const response = await app.inject({ method: "GET", url: "/healthz" });

    expect(response.headers["x-request-id"]).toMatch(/^[0-9a-f-]{36}$/);
  });
});

describe("GET /readyz", () => {
  it("reports the database as not configured without a pool", async () => {
    app = buildApp({ config, version: "test" });

    const response = await app.inject({ method: "GET", url: "/readyz" });

    expect(response.statusCode).toBe(200);
    expect(response.json()).toEqual({ status: "ok", checks: { database: "not configured" } });
  });

  it("is ok when the readiness check resolves", async () => {
    app = buildApp({ config, version: "test", readiness: () => Promise.resolve() });

    const response = await app.inject({ method: "GET", url: "/readyz" });

    expect(response.statusCode).toBe(200);
    expect(response.json()).toEqual({ status: "ok", checks: { database: "ok" } });
  });

  it("is 503 in the error envelope when the readiness check rejects", async () => {
    app = buildApp({
      config,
      version: "test",
      readiness: () => Promise.reject(new Error("no route to postgres")),
    });

    const response = await app.inject({
      method: "GET",
      url: "/readyz",
      headers: { "x-request-id": "r-1" },
    });

    expect(response.statusCode).toBe(503);
    expect(response.json()).toEqual({
      error: {
        code: "service_unavailable",
        message: "database unreachable",
        details: { database: "failed" },
        requestId: "r-1",
      },
    });
    expect(response.body).not.toContain("no route to postgres");
  });
});

describe("GET /metrics", () => {
  it("exposes process metrics and the request histogram by route", async () => {
    app = buildApp({ config, version: "test" });
    await app.inject({ method: "GET", url: "/healthz" });

    const response = await app.inject({ method: "GET", url: "/metrics" });

    expect(response.statusCode).toBe(200);
    expect(response.headers["content-type"]).toContain("text/plain");
    expect(response.body).toContain("process_cpu_user_seconds_total");
    expect(response.body).toContain(
      'http_request_duration_seconds_count{method="GET",route="/healthz",status="200"} 1',
    );
  });
});
