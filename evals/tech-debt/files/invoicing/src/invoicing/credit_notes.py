"""Credit notes against an issued invoice."""

from decimal import ROUND_HALF_UP, Decimal


def credit_note_total(lines, pct):
    total = Decimal("0")
    for amount in lines:
        part = Decimal(str(amount)) * Decimal(str(pct)) / 100
        total += part.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
    return total
