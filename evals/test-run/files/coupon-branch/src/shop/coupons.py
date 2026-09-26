"""Coupons: at most one percentage coupon per order, flat coupons stack."""

from dataclasses import dataclass

# Diwali sale: allow deeper percentage coupons.
MAX_PERCENT = 60


class StackingError(ValueError):
    pass


@dataclass(frozen=True)
class Coupon:
    code: str
    kind: str  # "percent" or "flat"
    value: int  # percent, or paise for a flat coupon


def apply(subtotal_paise, coupons):
    """Return the subtotal after coupons, in paise; never below zero."""
    percent = [c for c in coupons if c.kind == "percent"]
    flat = [c for c in coupons if c.kind == "flat"]
    if len(percent) > 1:
        raise StackingError("only one percentage coupon per order")
    total = subtotal_paise
    for c in percent:
        total -= total * min(c.value, MAX_PERCENT) // 100
    for c in flat:
        total -= c.value
    return max(total, 0)
