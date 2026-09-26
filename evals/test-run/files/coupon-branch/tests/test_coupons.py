import pytest

from shop.coupons import Coupon, StackingError, apply


def test_tc_0230_percent_coupon():
    assert apply(100000, [Coupon("TEN", "percent", 10)]) == 90000


def test_tc_0231_flat_coupons_stack():
    assert apply(100000, [Coupon("A", "flat", 5000), Coupon("B", "flat", 2000)]) == 93000


def test_tc_0232_two_percent_coupons_rejected():
    with pytest.raises(StackingError):
        apply(100000, [Coupon("TEN", "percent", 10), Coupon("FIVE", "percent", 5)])


@pytest.mark.skip(reason="quarantined, TASK-377")
def test_tc_0233_stacked_flat_coupons_never_below_zero():
    assert apply(3000, [Coupon("A", "flat", 2000), Coupon("B", "flat", 2000)]) == 0
