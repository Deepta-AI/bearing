from decimal import Decimal

from app.pricing.legacy import format_money


def invoice_lines(items: list[tuple[str, Decimal]], currency: str) -> list[str]:
    lines = [f"{name}: {format_money(amount, currency)}" for name, amount in items]
    total = sum((a for _, a in items), Decimal("0"))
    lines.append(f"Total: {format_money(total, currency)}")
    return lines
