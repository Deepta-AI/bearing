import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createApp } from '../src/server/app.js';
import { createStore } from '../src/server/store.js';
import { FakeProvider } from '../src/server/provider.js';
import { fakeAnalytics } from '../src/server/analytics.js';
import { reconcilePayments } from '../src/server/reconcile.js';

function setup() {
  const store = createStore();
  const provider = new FakeProvider();
  const analytics = fakeAnalytics();
  const handle = createApp({ store, provider, analytics, baseUrl: 'https://paylink.example' });
  return { store, provider, analytics, handle };
}

const merchant = { 'x-merchant-id': 'm_42' };
const draft = {
  customerName: 'Asha Rao',
  customerEmail: 'asha@example.com',
  currency: 'INR',
  lines: [{ description: 'Design work', qty: 2, unitMinor: 250000 }],
};

test('creating an invoice is tracked with its amount in minor units', async () => {
  const { handle, analytics } = setup();
  const res = await handle('POST', '/api/invoices', draft, merchant);
  assert.equal(res.status, 201);
  assert.deepEqual(analytics.events.map((e) => e.event), ['invoice_created']);
  assert.equal(analytics.events[0].props.amount_minor, 500000);
});

test('the payer can open the link and start a payment', async () => {
  const { handle, store, provider } = setup();
  const { body } = await handle('POST', '/api/invoices', draft, merchant);
  const token = store.byId(body.id).payToken;
  const view = await handle('GET', `/api/pay/${token}`);
  assert.equal(view.status, 200);
  assert.equal(view.body.amountMinor, 500000);
  const co = await handle('POST', `/api/pay/${token}/checkout`, { method: 'upi' });
  assert.equal(co.status, 200);
  assert.equal(provider.sessions.length, 1);
});

test('a signed payment.succeeded webhook marks the invoice paid', async () => {
  const { handle, store, provider } = setup();
  const { body } = await handle('POST', '/api/invoices', draft, merchant);
  const evt = {
    id: 'evt_1',
    type: 'payment.succeeded',
    created_at: '2026-10-02T10:00:00Z',
    data: { invoice_id: body.id, amount_minor: 500000, currency: 'INR', method: 'upi', failure_code: null, failure_message: null },
  };
  const res = await handle('POST', '/webhooks/payments', evt, { 'x-provider-signature': provider.sign(evt) });
  assert.equal(res.status, 200);
  assert.equal(store.byId(body.id).status, 'paid');
});

test('the access log never contains the pay token', async () => {
  const lines = [];
  const store = createStore();
  const handle = createApp({ store, provider: new FakeProvider(), analytics: fakeAnalytics(), baseUrl: 'x', log: (l) => lines.push(l) });
  const { body } = await handle('POST', '/api/invoices', draft, merchant);
  const token = store.byId(body.id).payToken;
  await handle('GET', `/api/pay/${token}`);
  assert.ok(lines.length === 2 && lines.every((l) => !l.includes(token)));
});

test('reconciliation marks paid a payment whose webhook never came', async () => {
  const { handle, store, provider } = setup();
  const { body } = await handle('POST', '/api/invoices', draft, merchant);
  const token = store.byId(body.id).payToken;
  await handle('POST', `/api/pay/${token}/checkout`, { method: 'netbanking' });
  assert.equal(await reconcilePayments(store, provider), 0);
  provider.settle('cs_1', 'succeeded', '2026-10-02T11:00:00Z');
  assert.equal(await reconcilePayments(store, provider), 1);
  assert.equal(store.byId(body.id).status, 'paid');
  assert.equal(store.byId(body.id).paidAt, '2026-10-02T11:00:00Z');
});

test('a merchant can mark an invoice paid by hand', async () => {
  const { handle, store } = setup();
  const { body } = await handle('POST', '/api/invoices', draft, merchant);
  const res = await handle('POST', `/api/invoices/${body.id}/mark-paid`, {}, merchant);
  assert.equal(res.status, 200);
  assert.equal(store.byId(body.id).paymentMethod, 'offline');
});
