import { describe, expect, it, vi } from "vitest";

import { GET } from "./route";

// connection() needs a live request; the unit test has none.
vi.mock("next/server", () => ({ connection: () => Promise.resolve() }));

describe("GET /api/healthz", () => {
  it("answers ok with the version", async () => {
    const response = await GET();

    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toEqual({ status: "ok", version: "dev" });
  });
});
