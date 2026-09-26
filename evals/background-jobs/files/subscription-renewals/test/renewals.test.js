import { test } from 'node:test';
import assert from 'node:assert/strict';
import { FakeProvider } from '../src/billing.js';
import { renewSubscriptions } from '../src/jobs/renew-subscriptions.js';
import { seededDb } from './helpers.js';

const OCT_1 = new Date('2026-10-01T02:30:00Z');

test('charges the subscriptions due on the 1st', async () => {
  const db = seededDb();
  const provider = new FakeProvider();
  const n = await renewSubscriptions(db, provider, OCT_1);
  assert.equal(n, 2);
  assert.deepEqual(provider.charges.map((c) => c.customerId), ['cus_1', 'cus_2']);
});

test('moves the next renewal a month on', async () => {
  const db = seededDb();
  await renewSubscriptions(db, new FakeProvider(), OCT_1);
  const row = db.prepare('SELECT next_renewal_at FROM subscriptions WHERE id = ?').get('sub_1');
  assert.equal(row.next_renewal_at, '2026-11-01T00:00:00.000Z');
});
