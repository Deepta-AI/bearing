import { test } from 'node:test';
import assert from 'node:assert/strict';
import { daysUntil, formatDate, formatMoney, overdueLabel } from '../src/lib/format.js';

test('formatMoney shows rupees from paise', () => {
  assert.equal(formatMoney(123456), 'Rs. 1,234.56');
});

test('formatDate is day first', () => {
  assert.equal(formatDate('2026-03-05T00:00:00Z'), '05/03/2026');
});

test('overdueLabel counts invoices', () => {
  assert.equal(overdueLabel(1), '1 invoice overdue');
  assert.equal(overdueLabel(3), '3 invoices overdue');
});

test('daysUntil rounds up', () => {
  assert.equal(daysUntil('2026-03-05T12:00:00Z', new Date('2026-03-04T00:00:00Z')), 2);
});
