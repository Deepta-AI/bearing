import { test } from 'node:test';
import assert from 'node:assert/strict';
import { parseReport } from '../src/parse.js';
import { verifySignature } from '../src/signature.js';
import { createHmac } from 'node:crypto';

test('assumes IST when collectedAt has no zone', () => {
  const r = parseReport({ labId: 7, patientRef: ' hc-001 ', collectedAt: '2026-09-01T09:00:00', results: [] });
  assert.equal(r.collectedAt.toISOString(), '2026-09-01T03:30:00.000Z');
  assert.equal(r.patientRef, 'HC-001');
});

test('rejects a report without results', () => {
  assert.throws(() => parseReport({ labId: 7, patientRef: 'x', collectedAt: '2026-09-01T09:00:00Z' }));
});

test('verifies a partner signature', () => {
  const body = Buffer.from('{"a":1}');
  const sig = createHmac('sha256', 'k').update(body).digest('hex');
  assert.equal(verifySignature('k', body, sig), true);
  assert.equal(verifySignature('k', Buffer.from('{"a":2}'), sig), false);
});
