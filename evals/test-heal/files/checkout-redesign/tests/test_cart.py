from datetime import date

from app.cart import Cart, Coupon


def test_expired_coupon_is_refused():
    cart = Cart()
    cart.add("SKU-1", 1, 1000_00)
    old = Coupon(code="OLD5", percent=5, expires=date(2026, 1, 31))
    assert not cart.apply_coupon(old, today=date(2026, 2, 1))
    assert cart.discount == 0


def test_coupon_valid_on_its_last_day():
    cart = Cart()
    cart.add("SKU-1", 1, 1000_00)
    c = Coupon(code="LAST", percent=5, expires=date(2026, 3, 31))
    assert cart.apply_coupon(c, today=date(2026, 3, 31))
    assert cart.discount == 50_00
