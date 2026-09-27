import { test, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { getPref, setPref } from '../src/lib/prefs.js';

function memoryStorage() {
  const m = new Map();
  return { getItem: (k) => (m.has(k) ? m.get(k) : null), setItem: (k, v) => m.set(k, String(v)), map: m };
}

afterEach(() => { delete globalThis.localStorage; });

test('stores under the inv. prefix', () => {
  const s = memoryStorage();
  globalThis.localStorage = s;
  assert.equal(setPref('density', 'compact'), true);
  assert.equal(s.map.get('inv.density'), 'compact');
  assert.equal(getPref('density', 'comfortable'), 'compact');
});

test('falls back when storage throws', () => {
  globalThis.localStorage = { getItem() { throw new Error('SecurityError'); }, setItem() { throw new Error('SecurityError'); } };
  assert.equal(getPref('density', 'comfortable'), 'comfortable');
  assert.equal(setPref('density', 'compact'), false);
});
