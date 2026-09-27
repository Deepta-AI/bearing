import { test } from 'node:test';
import assert from 'node:assert/strict';
import { parseStatement } from '../src/statement.js';

test('parses quoted memos and skips the header', () => {
  const rows = parseStatement(
    'date,ref,memo,amount\n2026-09-01,TX1,"Rent, September",-45000\n2026-09-02,TX2,UPI salary,120000.50\n',
  );
  assert.deepEqual(rows, [
    { date: '2026-09-01', ref: 'TX1', memo: 'Rent, September', amount: '-45000' },
    { date: '2026-09-02', ref: 'TX2', memo: 'UPI salary', amount: '120000.50' },
  ]);
});
