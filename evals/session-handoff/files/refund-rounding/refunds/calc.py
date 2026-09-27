"""Refund amounts for order lines."""
from decimal import ROUND_HALF_UP, Decimal

CENT = Decimal("0.01")
ROUNDING = ROUND_HALF_UP


def line_refund(unit_price: Decimal, qty_refunded: int, discount_pct: Decimal = Decimal("0")) -> Decimal:
    """Refund for qty_refunded units of one line, rounded to the cent."""
    if qty_refunded < 0:
        raise ValueError("qty_refunded must not be negative")
    gross = unit_price * qty_refunded
    net = gross * (Decimal("1") - discount_pct / Decimal("100"))
    return net.quantize(CENT, rounding=ROUNDING)


def order_refund(lines) -> Decimal:
    """Sum of the line refunds; each line is rounded on its own."""
    return sum((line_refund(*line) for line in lines), Decimal("0"))


def order_refund_rounded_once(lines) -> Decimal:
    # PAY-142: round the order total once instead of every line.
    # Which of the two finance wants is the open question in ADR 0003.
    raise NotImplementedError
