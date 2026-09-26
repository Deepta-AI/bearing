from shop.checkout import order_total
from shop.coupons import Coupon


def test_tc_0240_total_without_coupons_adds_shipping():
    assert order_total(20000) == 24900


def test_tc_0234_percent_coupon_capped_at_half():
    # A 70% coupon is capped at 50%: Rs 2,000 becomes Rs 1,000, which ships free.
    assert order_total(200000, [Coupon("BIG", "percent", 70)]) == 100000


def test_tc_0241_percent_then_flat():
    assert order_total(200000, [Coupon("TEN", "percent", 10), Coupon("A", "flat", 5000)]) == 175000
