import { drizzle, type NodePgDatabase } from "drizzle-orm/node-postgres";
import pg from "pg";

import * as schema from "./schema.js";

/** Db is the typed Drizzle handle repositories take. */
export type Db = NodePgDatabase<typeof schema>;

/** createPool builds the one pg pool per process. Nothing connects until the first query. */
export function createPool(databaseUrl: string, max: number): pg.Pool {
  return new pg.Pool({
    connectionString: databaseUrl,
    max,
    connectionTimeoutMillis: 5_000,
    idleTimeoutMillis: 30_000,
  });
}

/** createDb wraps the pool with the schema so queries are typed end to end. */
export function createDb(pool: pg.Pool): Db {
  return drizzle({ client: pool, schema });
}

/** pingDatabase rejects if the database cannot answer a trivial query. */
export async function pingDatabase(pool: pg.Pool): Promise<void> {
  await pool.query("SELECT 1");
}
