import pytest

from payouts.fees import platform_fee


def test_whole_paise_fee():
    assert platform_fee(10000, 250) == 250


def test_zero_rate_is_free():
    assert platform_fee(4999, 0) == 0


def test_negative_amount_rejected():
    with pytest.raises(ValueError):
        platform_fee(-1, 250)


def test_rate_above_100_percent_rejected():
    with pytest.raises(ValueError):
        platform_fee(100, 10001)
