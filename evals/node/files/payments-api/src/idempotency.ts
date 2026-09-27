import { and, eq } from 'drizzle-orm';
import type { Db, Tx } from './db/client.js';
import { idempotencyKeys } from './db/schema.js';

/** A stored or fresh response. */
export type Stored = { statusCode: number; body: unknown };

/**
 * Runs `fn` once per account and key inside one transaction and stores its
 * response; a repeat with the same key replays the stored response (ADR-0003).
 */
export async function withIdempotency(
  db: Db,
  accountId: string,
  key: string,
  fn: (tx: Tx) => Promise<Stored>,
): Promise<Stored> {
  return db.transaction(async (tx) => {
    const inserted = await tx
      .insert(idempotencyKeys)
      .values({ accountId, key, statusCode: 0, body: {} })
      .onConflictDoNothing()
      .returning();
    if (inserted.length === 0) {
      const [row] = await tx
        .select()
        .from(idempotencyKeys)
        .where(and(eq(idempotencyKeys.accountId, accountId), eq(idempotencyKeys.key, key)))
        .for('update');
      if (row && row.statusCode !== 0) return { statusCode: row.statusCode, body: row.body };
    }
    const result = await fn(tx);
    await tx
      .update(idempotencyKeys)
      .set({ statusCode: result.statusCode, body: result.body as object })
      .where(and(eq(idempotencyKeys.accountId, accountId), eq(idempotencyKeys.key, key)));
    return result;
  });
}
