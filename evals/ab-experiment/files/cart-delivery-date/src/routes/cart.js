import { track } from '../analytics.js';

export function isMobile(req) {
  return /Mobile|Android|iPhone/.test(req.headers['user-agent'] || '');
}

export function renderCart(req, cart) {
  const platform = isMobile(req) ? 'mobile' : 'desktop';
  track('cart_viewed', { user_id: req.userId ?? null, device_id: req.deviceId, platform });
  const lines = cart.items
    .map((i) => `<li>${i.name} x${i.qty}</li>`)
    .join('');
  return `<section class="cart cart--${platform}"><ul>${lines}</ul>` +
    `<a class="checkout" href="/checkout">Checkout</a></section>`;
}
