import type { Db } from '../db.ts';
import { NotFoundError } from '../errors.ts';
import { encodeCursor, type Cursor } from '../pagination.ts';
import { findCustomer, listCustomers, type Customer } from './repository.ts';

/** One customer of the account; NotFoundError when missing, deleted or another account's. */
export function getCustomer(db: Db, accountId: string, id: string): Customer {
  const c = findCustomer(db, accountId, id);
  if (!c) throw new NotFoundError('customer');
  return c;
}

/** One page of the account's customers and the cursor for the next page. */
export function pageCustomers(
  db: Db,
  accountId: string,
  limit: number,
  after: Cursor | null,
): { items: Customer[]; nextCursor: string | null } {
  // Fetch one extra row to know whether another page exists.
  const rows = listCustomers(db, accountId, limit + 1, after);
  const items = rows.slice(0, limit);
  const last = items.at(-1);
  const nextCursor = rows.length > limit && last ? encodeCursor({ createdAt: last.createdAt, id: last.id }) : null;
  return { items, nextCursor };
}
