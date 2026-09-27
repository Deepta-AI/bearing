"""Builders for carts and coupons used across the tests."""

from datetime import date

from app.cart import Cart, Coupon


def cart_of(*prices_in_rupees: int) -> Cart:
    cart = Cart()
    for i, rupees in enumerate(prices_in_rupees, start=1):
        cart.add(f"SKU-{i:03d}", 1, rupees * 100)
    return cart


def festival_coupon(percent: int = 10) -> Coupon:
    # The September festival campaign coupon.
    return Coupon(code="FEST10", percent=percent, expires=date(2026, 9, 25))
