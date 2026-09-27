import { test } from 'node:test';
import assert from 'node:assert/strict';
import { sortByCustomer } from '../src/lib/invoices.js';

test('sortByCustomer orders by customer name', () => {
  const out = sortByCustomer([{ customer: 'Mehta Traders' }, { customer: 'Arora Foods' }]);
  assert.deepEqual(out.map((i) => i.customer), ['Arora Foods', 'Mehta Traders']);
});
