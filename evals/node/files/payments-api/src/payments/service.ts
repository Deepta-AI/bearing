import { randomUUID } from 'node:crypto';
import type { Db } from '../db/client.js';
import { NotFoundError } from '../errors.js';
import { withIdempotency, type Stored } from '../idempotency.js';
import { findPayment, insertPayment, type Payment } from './repository.js';

/** One payment of the account; NotFoundError otherwise. */
export async function getPayment(db: Db, accountId: string, id: string): Promise<Payment> {
  const p = await findPayment(db, accountId, id);
  if (!p) throw new NotFoundError('payment');
  return p;
}

/** Records an authorised payment once per idempotency key. */
export async function createPayment(
  db: Db,
  accountId: string,
  key: string,
  input: { amountMinor: number; currency: string },
): Promise<Stored> {
  return withIdempotency(db, accountId, key, async (tx) => {
    const p = await insertPayment(tx, { id: `pay_${randomUUID()}`, accountId, status: 'authorized', ...input });
    return { statusCode: 201, body: p };
  });
}
