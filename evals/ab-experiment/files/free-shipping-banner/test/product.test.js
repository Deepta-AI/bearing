import { test } from 'node:test';
import assert from 'node:assert/strict';
import { assign } from '../src/assign.js';
import { renderProductPage } from '../src/web/product-page.js';
import { productScreen } from '../src/app/product-screen.js';

test('assignment is sticky per device', () => {
  assert.equal(assign('d-1', 'x', 50), assign('d-1', 'x', 50));
});

test('assignment splits close to half', () => {
  let t = 0;
  for (let i = 0; i < 10000; i++) if (assign(`d-${i}`, 'free-shipping-banner', 50) === 'treatment') t++;
  assert.ok(t > 4800 && t < 5200, `treatment ${t}`);
});

test('the web page shows the banner only to treatment', () => {
  for (let i = 0; i < 20; i++) {
    const ctx = { deviceId: `d-${i}`, product: { name: 'Mug' }, onImageLoad() {} };
    const html = renderProductPage(ctx);
    const v = assign(ctx.deviceId, 'free-shipping-banner', 50);
    assert.equal(html.includes('banner'), v === 'treatment');
  }
});

test('the app screen shows the banner only to treatment', () => {
  const s = productScreen({ deviceId: 'd-7', product: { name: 'Mug' } });
  assert.equal(s.banner !== null, assign('d-7', 'free-shipping-banner', 50) === 'treatment');
});
