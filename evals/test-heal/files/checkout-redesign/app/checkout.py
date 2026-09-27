"""Renders the checkout page (US-12-004 layout)."""

from html import escape

from app.cart import Cart


def rupees(paise: int) -> str:
    return f"₹{paise // 100:,}.{paise % 100:02d}"


def _summary(cart: Cart) -> str:
    coupon = (
        f'<p id="coupon-applied">{escape(cart.coupon.code)}: {cart.coupon.percent}% off</p>'
        if cart.coupon
        else ""
    )
    nudge = ""
    if cart.amount_to_free_shipping():
        nudge = f'<p class="nudge">Add {rupees(cart.amount_to_free_shipping())} more for free shipping</p>'
    return f"""<aside class="summary" aria-label="Order summary">
    {coupon}
    <p>Shipping: <span id="shipping-fee">{rupees(cart.shipping)}</span></p>
    {nudge}
    <p>Total: <strong id="order-total">{rupees(cart.total)}</strong></p>
  </aside>"""


def render_checkout(cart: Cart) -> str:
    rows = "".join(
        f"<tr><td>{escape(sku)}</td><td>{qty}</td><td>{rupees(qty * price)}</td></tr>"
        for sku, qty, price in cart.lines
    )
    return f"""<!doctype html>
<html lang="en">
<head><title>Checkout</title></head>
<body>
<main class="checkout two-col">
  <h1>Checkout</h1>
  <section class="items">
    <table id="lines">{rows}</table>
  </section>
  {_summary(cart)}
  <form method="post" action="/orders" class="actions">
    <label for="coupon-code">Coupon code</label>
    <input id="coupon-code" name="coupon">
    <a class="btn" href="/cart">Back to cart</a>
    <button class="btn" type="submit" formaction="/cart/save">Save for later</button>
    <button class="btn btn-primary cta" type="submit" data-testid="place-order">Place order</button>
  </form>
</main>
</body>
</html>"""
