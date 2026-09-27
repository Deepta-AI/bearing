import { test } from 'node:test';
import assert from 'node:assert/strict';
import { parsePaise, formatPaise } from '../src/amounts.js';

test('parses rupee text into paise', () => {
  assert.equal(parsePaise('1,250.5'), 125050n);
  assert.equal(parsePaise('-3'), -300n);
  assert.equal(parsePaise('0.07'), 7n);
  assert.throws(() => parsePaise('12.345'));
});

test('formats paise, including totals past 2^53', () => {
  assert.equal(formatPaise(-125050n), '-1250.50');
  assert.equal(formatPaise(900719925474099312n), '9007199254740993.12');
});
