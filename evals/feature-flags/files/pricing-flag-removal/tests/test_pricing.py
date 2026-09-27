from app.flags import Flag, Flags
from app.pricing.page import render_pricing


def test_new_pricing_on_shows_tiers():
    html = render_pricing(Flags({Flag.NEW_PRICING: True}), "USD", "us")
    assert 'class="tiers"' in html
    assert "legacy-prices" not in html
    assert '"new_pricing": true' in html


def test_new_pricing_off_shows_legacy_table():
    html = render_pricing(Flags({}), "USD", "us")
    assert "legacy-prices" in html
    assert 'class="tiers"' not in html


def test_eu_tier_prices_include_vat():
    html = render_pricing(Flags({Flag.NEW_PRICING: True}), "EUR", "eu")
    assert "€10.80/mo" in html  # 9.00 + 20% VAT
    assert "€108.00/yr" in html
