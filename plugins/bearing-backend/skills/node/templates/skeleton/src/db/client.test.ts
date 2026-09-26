import { describe, expect, it } from "vitest";

import { createDb, createPool } from "./client.js";

describe("createPool", () => {
  it("builds a pool with the configured size without connecting", async () => {
    const pool = createPool("postgres://postgres:postgres@localhost:5432/test", 3);

    expect(pool.options.max).toBe(3);
    expect(pool.totalCount).toBe(0);
    await pool.end();
  });
});

describe("createDb", () => {
  it("returns a typed Drizzle handle over the pool", async () => {
    const pool = createPool("postgres://postgres:postgres@localhost:5432/test", 1);
    const db = createDb(pool);

    expect(typeof db.select).toBe("function");
    expect(db.query.schemaProbe).toBeDefined();
    await pool.end();
  });
});
