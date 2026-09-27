"""Statement totals. Amounts are integer paise; never floats."""

from decimal import Decimal


def to_paise(amount: str) -> int:
    """Parse a rupee amount such as "1250.50" into paise."""
    return int((Decimal(amount) * 100).to_integral_exact())


def total_paise(amounts: list[str]) -> int:
    return sum(to_paise(a) for a in amounts)
