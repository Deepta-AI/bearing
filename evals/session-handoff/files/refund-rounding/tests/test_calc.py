from decimal import Decimal

import pytest

from refunds.calc import line_refund, order_refund


def test_full_line_refund():
    assert line_refund(Decimal("199.00"), 2) == Decimal("398.00")


def test_partial_line_refund():
    assert line_refund(Decimal("49.99"), 1) == Decimal("49.99")


def test_discount_applies_before_rounding():
    assert line_refund(Decimal("10.00"), 3, Decimal("12.5")) == Decimal("26.25")


def test_negative_quantity_is_rejected():
    with pytest.raises(ValueError):
        line_refund(Decimal("10.00"), -1)


def test_order_refund_sums_rounded_lines():
    lines = [(Decimal("0.335"), 1), (Decimal("0.335"), 1)]
    assert order_refund(lines) == Decimal("0.68")
