import { describe, expect, it, vi } from 'vitest';
import { buildApp } from '../app.js';
import type { Db } from '../db/client.js';
import * as service from '../payments/service.js';

vi.mock('../payments/service.js');

const db = {} as Db;
const headers = { 'x-account-id': 'acc_1' };

describe('payments routes', () => {
  it('returns the account payment', async () => {
    vi.mocked(service.getPayment).mockResolvedValue({
      id: 'pay_1',
      accountId: 'acc_1',
      amountMinor: 1250,
      currency: 'EUR',
      status: 'captured',
      createdAt: new Date('2026-06-01T00:00:00Z'),
    });
    const app = buildApp({ db, logLevel: 'silent', ledgerUrl: 'http://ledger.invalid' });
    const res = await app.inject({ method: 'GET', url: '/payments/pay_1', headers });
    expect(res.statusCode).toBe(200);
    expect(res.json().amountMinor).toBe(1250);
  });

  it('requires an idempotency key to create a payment', async () => {
    const app = buildApp({ db, logLevel: 'silent', ledgerUrl: 'http://ledger.invalid' });
    const res = await app.inject({
      method: 'POST',
      url: '/payments',
      headers,
      payload: { amountMinor: 1250, currency: 'EUR' },
    });
    expect(res.statusCode).toBe(400);
    expect(res.json().error.code).toBe('validation_error');
  });
});
