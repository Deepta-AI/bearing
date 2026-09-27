import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createAnalytics } from '../src/analytics/index.js';
import { onNavigate } from '../src/router.js';

function make() {
  const posted = [];
  const analytics = createAnalytics({ post: (url, body) => posted.push({ url, body }), appVersion: '3.2.0' });
  return { posted, analytics };
}

test('nothing is posted before consent', () => {
  const { posted, analytics } = make();
  assert.equal(analytics.track('test_event', { a: 1 }), false);
  assert.equal(posted.length, 0);
});

test('after consent an event is posted to the collector', () => {
  const { posted, analytics } = make();
  analytics.setConsent(true);
  analytics.track('test_event', { a: 1 });
  assert.equal(posted.length, 1);
  assert.equal(posted[0].url, '/collect');
  assert.equal(posted[0].body.context.platform, 'web');
});

test('navigation emits screen_viewed for known screens only', () => {
  const { posted, analytics } = make();
  analytics.setConsent(true);
  onNavigate(analytics, '/p/atta-5kg');
  onNavigate(analytics, '/about');
  assert.deepEqual(posted.map((p) => p.body.props.screen), ['product']);
});
