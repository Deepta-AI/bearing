import { test } from 'node:test';
import assert from 'node:assert/strict';
import { retry } from '../src/index.js';

const fast = { baseMs: 1, maxMs: 2 };

test('retries until the call succeeds', async () => {
  let calls = 0;
  const out = await retry(async () => {
    calls++;
    if (calls < 3) throw new Error('flaky');
    return 'ok';
  }, fast);
  assert.equal(out, 'ok');
  assert.equal(calls, 3);
});

test('does not retry a 404', async () => {
  let calls = 0;
  await assert.rejects(retry(async () => {
    calls++;
    throw Object.assign(new Error('not found'), { status: 404 });
  }, fast));
  assert.equal(calls, 1);
});

test('retries a 429', async () => {
  let calls = 0;
  await assert.rejects(retry(async () => {
    calls++;
    throw Object.assign(new Error('slow down'), { status: 429 });
  }, { ...fast, retries: 2 }));
  assert.equal(calls, 3);
});

test('times out a hung attempt', async () => {
  await assert.rejects(retry(() => new Promise(() => {}), { ...fast, retries: 0, timeoutMs: 20 }), /timed out/);
});
