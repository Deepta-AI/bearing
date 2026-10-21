"""Render an order as a plain-text receipt."""

from receipts.money import rupees

WIDTH = 32


def line(label: str, paise: int) -> str:
    amount = rupees(paise)
    return f"{label[: WIDTH - len(amount) - 1]:<{WIDTH - len(amount)}}{amount}"


def render(order_id: str, items: list[tuple[str, int, int]]) -> str:
    """items: (name, quantity, unit price in paise)."""
    rows = [f"Receipt {order_id}", "-" * WIDTH]
    total = 0
    for name, qty, unit in items:
        total += qty * unit
        rows.append(line(f"{qty} x {name}", qty * unit))
    rows.append("-" * WIDTH)
    rows.append(line("Total", total))
    return "\n".join(rows) + "\n"
