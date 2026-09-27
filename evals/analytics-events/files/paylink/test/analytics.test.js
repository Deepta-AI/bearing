import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createAnalytics } from '../src/web/analytics/index.js';

function make() {
  const sent = [];
  const analytics = createAnalytics({
    send: (p) => sent.push(p),
    appVersion: '1.4.0',
    location: { pathname: '/app/invoices' },
  });
  return { sent, analytics };
}

test('nothing is sent before consent', () => {
  const { sent, analytics } = make();
  assert.equal(analytics.screen('invoices'), false);
  assert.equal(sent.length, 0);
  assert.equal(analytics.dropped, 1);
});

test('after consent the event carries the standard context', () => {
  const { sent, analytics } = make();
  analytics.setConsent(true);
  analytics.setTenant('m_42');
  analytics.track('invoice_sent', { invoice_id: 'inv_00001', channel: 'email' });
  assert.equal(sent.length, 1);
  assert.deepEqual(sent[0].context, {
    app_version: '1.4.0',
    platform: 'web',
    tenant_id: 'm_42',
    page_path: '/app/invoices',
  });
});

test('an event outside the catalogue is refused', () => {
  const { analytics } = make();
  assert.throws(() => analytics.track('invoice_opened', {}), /unknown event/);
});

test('a property outside the catalogue is refused', () => {
  const { analytics } = make();
  assert.throws(
    () => analytics.track('invoice_sent', { invoice_id: 'inv_00001', channel: 'email', to: 'a@example.com' }),
    /has no property/,
  );
});
