import { test } from 'node:test';
import assert from 'node:assert/strict';
import { formatMoney } from '../src/lib/format.js';

test('formats paise as rupees', () => {
  assert.equal(formatMoney(124000), '₹1,240.00');
});
