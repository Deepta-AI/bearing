import { describe, expect, it } from 'vitest';
import { buildApp } from '../app.js';
import type { Db } from '../db/client.js';

const captured = {
  id: 'pay_1',
  accountId: 'acc_1',
  amountMinor: 5000,
  currency: 'EUR',
  status: 'captured',
  createdAt: new Date('2026-06-01T00:00:00Z'),
};

// A chainable stand-in for the Drizzle calls the refund route makes.
function fakeDb(): Db {
  const chain = (result: unknown) => {
    const c: Record<string, unknown> = {};
    for (const m of ['from', 'where', 'orderBy', 'values']) c[m] = () => c;
    c.returning = async () => [{ id: 'ref_1', paymentId: 'pay_1', amountMinor: 2000, reason: 'damaged' }];
    c.then = (ok: (v: unknown) => unknown) => Promise.resolve(result).then(ok);
    return c;
  };
  let selects = 0;
  return {
    select: () => chain(selects++ === 0 ? [captured] : [{ refunded: 0 }]),
    insert: () => chain([]),
  } as unknown as Db;
}

describe('refund routes', () => {
  it('refunds part of a captured payment', async () => {
    const app = buildApp({ db: fakeDb(), logLevel: 'silent', ledgerUrl: 'http://ledger.invalid' });
    const res = await app.inject({
      method: 'POST',
      url: '/payments/pay_1/refunds',
      headers: { 'x-account-id': 'acc_1' },
      payload: { amountMinor: 2000, reason: 'damaged' },
    });
    expect(res.statusCode).toBe(201);
    expect(res.json().amountMinor).toBe(2000);
  });
});
