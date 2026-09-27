import { test } from 'node:test';
import assert from 'node:assert/strict';
import { variantFor } from '../src/flags.js';

test('the same key always gets the same variant', () => {
  const req = { sessionId: 's-123' };
  const flags = { exp: { percent: 50 } };
  assert.equal(variantFor('exp', req, flags), variantFor('exp', req, flags));
});

test('an unknown flag is control', () => {
  assert.equal(variantFor('missing', { sessionId: 's-1' }), 'control');
});

test('percent 100 is always treatment', () => {
  const flags = { all: { percent: 100 } };
  for (let i = 0; i < 50; i++) {
    assert.equal(variantFor('all', { sessionId: `s-${i}` }, flags), 'treatment');
  }
});
