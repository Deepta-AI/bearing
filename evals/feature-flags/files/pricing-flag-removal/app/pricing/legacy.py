"""The legacy single pricing table, and money formatting shared with invoices."""

from decimal import ROUND_HALF_UP, Decimal

from app.pricing.plans import PLANS

SYMBOLS = {"USD": "$", "EUR": "€"}


def format_money(amount: Decimal, currency: str) -> str:
    q = amount.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
    return f"{SYMBOLS.get(currency, currency + ' ')}{q:,}"


def legacy_price_table(currency: str) -> str:
    rows = "".join(
        f"<tr><td>{p['name']}</td><td>{format_money(p['monthly'], currency)}/mo</td></tr>"
        for p in PLANS
    )
    return f'<table class="legacy-prices">{rows}</table>'
