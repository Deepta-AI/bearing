import { describe, expect, it, vi } from "vitest";

import { jsonResponse } from "@/test/render";

import { GET } from "./route";

// connection() needs a live request; the unit test has none.
vi.mock("next/server", () => ({ connection: () => Promise.resolve() }));

describe("GET /api/readyz", () => {
  it("is ok when the API answers", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn(() => Promise.resolve(jsonResponse({ status: "ok" }))),
    );

    const response = await GET();

    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toEqual({ status: "ok", checks: { api: "ok" } });
  });

  it("is 503 when the API is down or unreachable", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn(() => Promise.resolve(jsonResponse({ status: "down" }, 503))),
    );
    expect((await GET()).status).toBe(503);

    vi.stubGlobal(
      "fetch",
      vi.fn(() => Promise.reject(new TypeError("offline"))),
    );
    const response = await GET();
    expect(response.status).toBe(503);
    await expect(response.json()).resolves.toEqual({
      status: "unavailable",
      checks: { api: "failed" },
    });
  });
});
