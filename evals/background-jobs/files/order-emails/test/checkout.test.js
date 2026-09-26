import { test } from 'node:test';
import assert from 'node:assert/strict';
import { openDb, migrate } from '../src/db.js';
import { Mailer, FakeRelay } from '../src/mailer.js';
import { placeOrder } from '../src/checkout.js';

function freshDb() {
  const db = openDb(':memory:');
  migrate(db);
  return db;
}

test('the order is stored with its total', async () => {
  const db = freshDb();
  const id = await placeOrder(db, new Mailer(new FakeRelay()), 'asha@example.com', [
    { sku: 'TEA-250', qty: 2, pricePaise: 34900 },
  ]);
  const row = db.prepare('SELECT total_paise FROM orders WHERE id = ?').get(id);
  assert.equal(row.total_paise, 69800);
});

test('the confirmation email is sent', async () => {
  const db = freshDb();
  const relay = new FakeRelay();
  await placeOrder(db, new Mailer(relay), 'asha@example.com', [{ sku: 'TEA-250', qty: 1, pricePaise: 34900 }]);
  assert.equal(relay.sent.length, 1);
  assert.equal(relay.sent[0].to, 'asha@example.com');
});
