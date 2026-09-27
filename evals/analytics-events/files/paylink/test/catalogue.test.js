import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { EVENTS } from '../src/shared/events.js';

function readSheet() {
  const text = readFileSync(new URL('../docs/analytics/EVENT_SHEET.md', import.meta.url), 'utf8');
  const sheet = {};
  for (const line of text.split('\n')) {
    if (!line.startsWith('| `')) continue;
    const cells = line.split('|').map((c) => c.trim());
    const name = cells[1].replaceAll('`', '');
    const props = {};
    for (const p of cells[3].split(';')) {
      const clean = p.replaceAll('`', '').trim();
      if (!clean) continue;
      const i = clean.indexOf(':');
      props[clean.slice(0, i).trim()] = clean.slice(i + 1).trim();
    }
    sheet[name] = props;
  }
  return sheet;
}

test('the sheet has events', () => {
  const n = Object.keys(readSheet()).length;
  assert.ok(n > 0, 'no event rows parsed from the sheet');
  console.log(`catalogue: ${n} events in the sheet, ${Object.keys(EVENTS).length} in the catalogue`);
});

test('the catalogue equals the event sheet', () => {
  assert.deepEqual(EVENTS, readSheet());
});
