import { test } from 'node:test';
import assert from 'node:assert/strict';
import { backoff } from '../src/index.js';

test('doubles per attempt and caps at maxMs', () => {
  assert.deepEqual([1, 2, 3, 4].map((a) => backoff(a, { baseMs: 100, maxMs: 500 })), [100, 200, 400, 500]);
});

test('jitter stays between 0 and the capped delay', () => {
  assert.equal(backoff(3, { baseMs: 100, jitter: true, random: () => 0.5 }), 200);
  assert.equal(backoff(3, { baseMs: 100, jitter: true, random: () => 0 }), 0);
});
