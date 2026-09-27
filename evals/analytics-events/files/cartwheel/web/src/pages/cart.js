export function onCartOpen(analytics, cart) {
  analytics.track('cart_viewed', { item_count: cart.lines.length, cart_value_minor: cart.totalMinor });
}

export async function applyCoupon(api, cart, code) {
  const res = await api.post('/api/cart/coupon', { code });
  cart.discountMinor = res.discountMinor;
  cart.totalMinor = res.totalMinor;
  return res;
}

export function onCheckoutClick(analytics, cart, navigate) {
  analytics.track('checkout_started', { cart_value: cart.totalMinor / 100, items: cart.lines.length });
  navigate('/checkout');
}
