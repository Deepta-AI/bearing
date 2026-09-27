"""Cart totals for the payment page."""

from decimal import Decimal

from shop.coupons import CouponError, discount_for


def cart_total(items, coupon=None):
    """Return (subtotal, discount, total, message) for a list of
    {"price": "...", "qty": n} items and an optional coupon code."""
    subtotal = sum((Decimal(i["price"]) * i["qty"] for i in items), Decimal("0.00"))
    discount, message = Decimal("0.00"), ""
    if coupon:
        try:
            discount = discount_for(coupon, subtotal)
        except CouponError as e:
            message = str(e)
    return subtotal, discount, subtotal - discount, message
