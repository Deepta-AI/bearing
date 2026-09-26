import { afterEach, describe, expect, it } from "vitest";
import { z } from "zod";

import { buildApp, type App } from "./app.js";
import { loadConfig } from "./config.js";
import { AppError, ConflictError, NotFoundError } from "./errors.js";

const config = loadConfig({ NODE_ENV: "test", LOG_LEVEL: "silent" });
let app: App | undefined;

afterEach(async () => {
  await app?.close();
  app = undefined;
});

describe("AppError", () => {
  it("carries status, code and details with sensible defaults", () => {
    const base = new AppError("bad");
    const missing = new NotFoundError("invoice 7", { details: { id: 7 } });
    const clash = new ConflictError("stale", { cause: new Error("version") });

    expect([base.statusCode, base.code, base.details]).toEqual([400, "bad_request", {}]);
    expect([missing.statusCode, missing.code, missing.details]).toEqual([
      404,
      "not_found",
      { id: 7 },
    ]);
    expect([clash.statusCode, clash.code, clash.name]).toEqual([409, "conflict", "ConflictError"]);
    expect(clash.cause).toBeInstanceOf(Error);
  });
});

describe("error envelope", () => {
  it("maps a domain error thrown by a handler", async () => {
    app = buildApp({ config, version: "test" });
    app.get("/boom", () => {
      throw new NotFoundError("invoice 7", { details: { id: 7 } });
    });

    const response = await app.inject({ method: "GET", url: "/boom" });

    expect(response.statusCode).toBe(404);
    expect(response.json()).toEqual({
      error: {
        code: "not_found",
        message: "invoice 7",
        details: { id: 7 },
        requestId: response.headers["x-request-id"],
      },
    });
  });

  it("maps a schema validation failure to 400 with the issues", async () => {
    app = buildApp({ config, version: "test" });
    app.get(
      "/items",
      { schema: { querystring: z.object({ limit: z.coerce.number().int().max(100) }) } },
      (request) => ({ limit: request.query.limit }),
    );

    const response = await app.inject({ method: "GET", url: "/items?limit=500" });

    expect(response.statusCode).toBe(400);
    const body = response.json<{
      error: { code: string; details: { issues: { path: string; message: string }[] } };
    }>();
    expect(body.error.code).toBe("validation_error");
    expect(body.error.details.issues).toHaveLength(1);
    expect(body.error.details.issues[0]?.path).toBe("/limit");
    expect(body.error.details.issues[0]?.message).toContain("100");
  });

  it("answers an unknown route with the envelope", async () => {
    app = buildApp({ config, version: "test" });

    const response = await app.inject({ method: "GET", url: "/nope" });

    expect(response.statusCode).toBe(404);
    expect(response.json()).toMatchObject({
      error: { code: "not_found", message: "route GET /nope not found" },
    });
  });

  it("keeps a client status from a Fastify error", async () => {
    app = buildApp({ config, version: "test" });

    const response = await app.inject({
      method: "POST",
      url: "/healthz",
      headers: { "content-type": "application/json" },
      payload: "{not json",
    });

    expect(response.statusCode).toBe(400);
    expect(response.json()).toMatchObject({ error: { code: "http_error" } });
  });

  it("hides the detail of an unhandled error behind a 500", async () => {
    app = buildApp({ config, version: "test" });
    app.get("/crash", () => {
      throw new Error("secret internals");
    });

    const response = await app.inject({ method: "GET", url: "/crash" });

    expect(response.statusCode).toBe(500);
    expect(response.body).not.toContain("secret internals");
    expect(response.json()).toEqual({
      error: {
        code: "internal",
        message: "internal error",
        details: {},
        requestId: response.headers["x-request-id"],
      },
    });
  });

  it("hides a response that fails its own schema behind a 500", async () => {
    app = buildApp({ config, version: "test" });
    app.get(
      "/shape",
      { schema: { response: { 200: z.object({ count: z.number() }) } } },
      () => ({ count: "many" }) as unknown as { count: number },
    );

    const response = await app.inject({ method: "GET", url: "/shape" });

    expect(response.statusCode).toBe(500);
    expect(response.json()).toMatchObject({ error: { code: "internal" } });
  });
});
