"""Invoices: line items, tax, totals, discounts, numbering and rendering.

Everything grew here. Amounts are whole paise.
"""

import logging
from dataclasses import dataclass, field

logger = logging.getLogger(__name__)

TAX_RATES = {"KA": 0.18, "MH": 0.18, "TN": 0.12, "DL": 0.05}
DEFAULT_REGION = "KA"
MAX_DISCOUNT_PERCENT = 30

_next_number = 1


# Models ------------------------------------------------------------------


@dataclass(frozen=True)
class LineItem:
    sku: str
    description: str
    quantity: int
    unit_paise: int

    @property
    def amount_paise(self):
        return self.quantity * self.unit_paise


@dataclass
class Invoice:
    number: str
    customer: str
    region: str
    items: list = field(default_factory=list)

    def add(self, item):
        if item.quantity <= 0:
            raise ValueError(f"quantity must be positive, got {item.quantity}")
        self.items.append(item)


def parse_line(text):
    """Parse 'SKU|Description|qty|unit_paise' into a LineItem."""
    parts = [p.strip() for p in text.split("|")]
    if len(parts) != 4:
        raise ValueError(f"expected 4 fields, got {len(parts)}: {text!r}")
    sku, description, qty, unit = parts
    return LineItem(sku, description, int(qty), int(unit))


# Tax ---------------------------------------------------------------------


def tax_rate(region):
    rate = TAX_RATES.get(region)
    if rate is None:
        logger.warning(
            "tax rate missing for region %s, using %s", region, DEFAULT_REGION
        )
        rate = TAX_RATES[DEFAULT_REGION]
    return rate


def compute_tax(amount_paise, region):
    """Tax on one amount, rounded to the paisa."""
    return round(amount_paise * tax_rate(region))


# Totals ------------------------------------------------------------------


def subtotal(invoice):
    return sum(i.amount_paise for i in invoice.items)


def compute_totals(invoice):
    sub = subtotal(invoice)
    tax = sum(compute_tax(i.amount_paise, invoice.region) for i in invoice.items)
    return {"subtotal": sub, "tax": tax, "total": sub + tax}


def apply_discount(invoice, percent):
    """Add a negative line for a percentage discount on the subtotal."""
    if not 0 < percent <= MAX_DISCOUNT_PERCENT:
        raise ValueError(f"discount must be 1 to {MAX_DISCOUNT_PERCENT} percent")
    amount = subtotal(invoice) * percent // 100
    invoice.items.append(LineItem("DISC", f"Discount {percent}%", 1, -amount))
    logger.info("discount %s%% applied to %s", percent, invoice.number)
    return amount


# Numbering ---------------------------------------------------------------


def next_invoice_number():
    global _next_number
    n = _next_number
    _next_number += 1
    return f"INV-{n:05d}"


def reset_numbering(start=1):
    global _next_number
    _next_number = start


# Rendering ---------------------------------------------------------------


def format_money(paise):
    sign = "-" if paise < 0 else ""
    rupees, p = divmod(abs(paise), 100)
    return f"{sign}Rs {rupees:,}.{p:02d}"


def render_text(invoice):
    totals = compute_totals(invoice)
    lines = [
        f"Invoice {invoice.number}",
        f"Customer: {invoice.customer}  Region: {invoice.region}",
        "",
    ]
    for item in invoice.items:
        lines.append(
            f"{item.sku:<8} {item.description:<24} {item.quantity:>3} x "
            f"{format_money(item.unit_paise):>12} = {format_money(item.amount_paise):>12}"
        )
    lines += [
        "",
        f"{'Subtotal':<44}{format_money(totals['subtotal']):>16}",
        f"{'GST':<44}{format_money(totals['tax']):>16}",
        f"{'Total':<44}{format_money(totals['total']):>16}",
    ]
    return "\n".join(lines) + "\n"
