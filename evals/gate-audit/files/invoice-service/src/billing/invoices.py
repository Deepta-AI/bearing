"""Invoice totals and numbering."""

from dataclasses import dataclass, field

GST_RATE_BPS = 1800  # 18 percent, in basis points


@dataclass
class Line:
    description: str
    unit_minor: int
    quantity: int = 1


@dataclass
class Invoice:
    invoice_id: str
    customer_id: str
    currency: str
    lines: list = field(default_factory=list)

    def subtotal_minor(self) -> int:
        return sum(l.unit_minor * l.quantity for l in self.lines)

    def tax_minor(self) -> int:
        # Round half up on the whole invoice, not per line.
        return (self.subtotal_minor() * GST_RATE_BPS + 5000) // 10000

    def total_minor(self) -> int:
        return self.subtotal_minor() + self.tax_minor()


def next_invoice_id(last_id: str) -> str:
    prefix, num = last_id.split("_")
    return f"{prefix}_{int(num) + 1}"
