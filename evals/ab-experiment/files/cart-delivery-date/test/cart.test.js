import { test } from 'node:test';
import assert from 'node:assert/strict';
import { renderCart } from '../src/routes/cart.js';

test('mobile user agents get the mobile cart', () => {
  const html = renderCart(
    { headers: { 'user-agent': 'Mozilla/5.0 (iPhone)' }, deviceId: 'd1' },
    { items: [{ name: 'Mug', qty: 2 }] },
  );
  assert.match(html, /cart--mobile/);
});
