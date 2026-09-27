// The checkout page. mount() runs every time /checkout is shown, whether the
// shopper came from the cart's Checkout button or reloaded the page.
export function mount(analytics, cart) {
  analytics.track('checkout_started', { cart_value: cart.totalMinor / 100, items: cart.lines.length });
  return renderCheckout(cart);
}

function renderCheckout(cart) {
  return `<form id="payment">
  <p>Total: ₹${(cart.totalMinor / 100).toFixed(2)}</p>
  <label><input type="radio" name="method" value="card" checked> Card</label>
  <label><input type="radio" name="method" value="upi"> UPI</label>
  <label><input type="radio" name="method" value="cod"> Cash on delivery</label>
  <button type="submit">Place order</button>
</form>`;
}

export async function submitPayment(api, analytics, method, navigate) {
  analytics.track('payment_submitted', { method });
  const order = await api.post('/api/orders', { method });
  navigate(`/order/confirmed?id=${order.id}`);
}
