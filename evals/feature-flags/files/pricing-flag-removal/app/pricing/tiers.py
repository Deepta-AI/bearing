"""The tiered pricing page with the monthly/annual toggle."""

from decimal import Decimal

from app.pricing.legacy import format_money
from app.pricing.plans import PLANS, VAT


def tier_cards(currency: str, region: str) -> str:
    vat = VAT.get(region, Decimal("0"))
    cards = []
    for p in PLANS:
        monthly = p["monthly"] * (1 + vat)
        annual = monthly * 10
        cards.append(
            f'<div class="tier" data-plan="{p["id"]}">'
            f"<h3>{p['name']}</h3>"
            f'<span class="price monthly">{format_money(monthly, currency)}/mo</span>'
            f'<span class="price annual" hidden>{format_money(annual, currency)}/yr</span>'
            "</div>"
        )
    toggle = '<button id="billing-toggle">Show annual prices</button>'
    return toggle + '<div class="tiers">' + "".join(cards) + "</div>"
