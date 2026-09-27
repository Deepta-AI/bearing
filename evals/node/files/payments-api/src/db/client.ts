import { drizzle, type NodePgDatabase } from 'drizzle-orm/node-postgres';
import type { Pool } from 'pg';
import * as schema from './schema.js';

/** The typed database handle repositories take. */
export type Db = NodePgDatabase<typeof schema>;

/** A transaction handle, accepted wherever a Db is. */
export type Tx = Parameters<Parameters<Db['transaction']>[0]>[0];

/** Wraps the process's one pool. */
export function createDb(pool: Pool): Db {
  return drizzle(pool, { schema });
}
