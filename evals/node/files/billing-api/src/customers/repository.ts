import type { Db } from '../db.ts';
import type { Cursor } from '../pagination.ts';

/** A customer row as the API sees it. */
export type Customer = { id: string; name: string; email: string; createdAt: string };

type Row = { id: string; name: string; email: string; created_at: string };

const toCustomer = (r: Row): Customer => ({ id: r.id, name: r.name, email: r.email, createdAt: r.created_at });

/** One live customer of the account, or null (also null when another account owns it). */
export function findCustomer(db: Db, accountId: string, id: string): Customer | null {
  const row = db
    .prepare(
      'SELECT id, name, email, created_at FROM customers WHERE account_id = ? AND id = ? AND deleted_at IS NULL',
    )
    .get(accountId, id) as Row | undefined;
  return row ? toCustomer(row) : null;
}

/** Up to `limit` live customers of the account, newest first, strictly after `after`. */
export function listCustomers(db: Db, accountId: string, limit: number, after: Cursor | null): Customer[] {
  const rows = after
    ? db
        .prepare(
          `SELECT id, name, email, created_at FROM customers
           WHERE account_id = ? AND deleted_at IS NULL AND (created_at, id) < (?, ?)
           ORDER BY created_at DESC, id DESC LIMIT ?`,
        )
        .all(accountId, after.createdAt, after.id, limit)
    : db
        .prepare(
          `SELECT id, name, email, created_at FROM customers
           WHERE account_id = ? AND deleted_at IS NULL
           ORDER BY created_at DESC, id DESC LIMIT ?`,
        )
        .all(accountId, limit);
  return (rows as Row[]).map(toCustomer);
}
