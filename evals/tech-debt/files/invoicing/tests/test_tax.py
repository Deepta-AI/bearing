from decimal import Decimal

from invoicing.tax import gst


def test_gst_at_18():
    assert gst(1000) == Decimal("180.00")


def test_reverse_charge_is_zero():
    assert gst(1000, reverse_charge=True) == Decimal("0.00")
