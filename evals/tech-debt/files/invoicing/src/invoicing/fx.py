"""Convert foreign-currency invoices to INR at the day's rate."""

from decimal import Decimal


def to_inr(amount, rate):
    return Decimal(amount) * rate  # type: ignore[arg-type]
