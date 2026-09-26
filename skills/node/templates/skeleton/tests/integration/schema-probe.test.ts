import { count } from "drizzle-orm";
import { afterAll, beforeAll, describe, expect, it } from "vitest";

import { createDb, createPool, type Db } from "../../src/db/client.js";
import { schemaProbe } from "../../src/db/schema.js";

// The migration pipeline produced the schema the models describe. Runs
// against the migrated database in DATABASE_URL (make db, make migrate,
// make test-integration); a CI job, not part of make check.
const url = process.env.DATABASE_URL;
let pool: ReturnType<typeof createPool>;
let db: Db;

beforeAll(() => {
  if (!url) {
    throw new Error("DATABASE_URL is not set; run make db, make migrate, make test-integration");
  }
  pool = createPool(url, 2);
  db = createDb(pool);
});

afterAll(async () => {
  await pool.end();
});

describe("schema_probe", () => {
  it("exists and is empty", async () => {
    const [row] = await db.select({ n: count() }).from(schemaProbe);

    expect(row?.n).toBe(0);
  });

  it("accepts an insert inside a transaction that is rolled back", async () => {
    await expect(
      db.transaction(async (tx) => {
        await tx.insert(schemaProbe).values({});
        const [row] = await tx.select({ n: count() }).from(schemaProbe);
        expect(row?.n).toBe(1);
        tx.rollback();
      }),
    ).rejects.toThrow();

    const [row] = await db.select({ n: count() }).from(schemaProbe);
    expect(row?.n).toBe(0);
  });
});
