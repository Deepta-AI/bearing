"""Renders the checkout page."""

from html import escape

from app.cart import Cart


def rupees(paise: int) -> str:
    return f"₹{paise // 100:,}.{paise % 100:02d}"


def render_checkout(cart: Cart) -> str:
    rows = "".join(
        f"<tr><td>{escape(sku)}</td><td>{qty}</td><td>{rupees(qty * price)}</td></tr>"
        for sku, qty, price in cart.lines
    )
    coupon = (
        f'<p id="coupon-applied">{escape(cart.coupon.code)}: {cart.coupon.percent}% off</p>'
        if cart.coupon
        else ""
    )
    disabled = " disabled" if cart.empty else ""
    return f"""<!doctype html>
<html lang="en">
<head><title>Checkout</title></head>
<body>
<main>
  <h1>Checkout</h1>
  <table id="lines">{rows}</table>
  {coupon}
  <p>Shipping: <span id="shipping-fee">{rupees(cart.shipping)}</span></p>
  <p>Total: <strong id="order-total">{rupees(cart.total)}</strong></p>
  <form method="post" action="/orders">
    <label for="coupon-code">Coupon code</label>
    <input id="coupon-code" name="coupon">
    <button id="pay-btn" class="btn btn-primary" type="submit"{disabled}>Pay now</button>
  </form>
</main>
</body>
</html>"""
