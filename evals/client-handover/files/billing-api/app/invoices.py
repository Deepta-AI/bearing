"""Invoice arithmetic. Amounts are integer paise; GST is added per line."""

from dataclasses import dataclass

GST_RATE_BP = 1800  # 18 percent, in basis points


@dataclass(frozen=True)
class Line:
    description: str
    quantity: int
    unit_paise: int


def line_total(line: Line) -> int:
    net = line.quantity * line.unit_paise
    # Round half up to the paisa, as Riverton's finance team asked (BIL-88).
    gst = (net * GST_RATE_BP + 5000) // 10000
    return net + gst


def invoice_total(lines: list[Line]) -> int:
    # TODO: credit notes are not netted here yet (BIL-131).
    return sum(line_total(l) for l in lines)


def payment_status(paid_paise: int, total_paise: int) -> str:
    if paid_paise <= 0:
        return "unpaid"
    if paid_paise < total_paise:
        return "partial"
    # FIXME: overpayments are reported as paid and the excess is not tracked.
    return "paid"
