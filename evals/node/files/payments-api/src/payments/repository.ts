import { and, eq } from 'drizzle-orm';
import type { Db, Tx } from '../db/client.js';
import { payments } from '../db/schema.js';

/** A payment row. */
export type Payment = typeof payments.$inferSelect;

/** The account's payment, or undefined (also for another account's id). */
export async function findPayment(db: Db | Tx, accountId: string, id: string): Promise<Payment | undefined> {
  const [row] = await db
    .select()
    .from(payments)
    .where(and(eq(payments.accountId, accountId), eq(payments.id, id)));
  return row;
}

/** Inserts a payment and returns it. */
export async function insertPayment(db: Db | Tx, values: typeof payments.$inferInsert): Promise<Payment> {
  const [row] = await db.insert(payments).values(values).returning();
  if (!row) throw new Error('insert returned no row');
  return row;
}
