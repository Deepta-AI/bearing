from decimal import Decimal

from refunds.calc import line_refund


def test_line_refund_rounds_half_to_even():
    # 0.125 sits exactly between 0.12 and 0.13; half-even keeps 0.12.
    assert line_refund(Decimal("0.125"), 1) == Decimal("0.12")


def test_whole_cents_are_unchanged():
    assert line_refund(Decimal("0.13"), 1) == Decimal("0.13")
