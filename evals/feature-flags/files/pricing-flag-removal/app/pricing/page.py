import json

from app.flags import Flag, Flags
from app.pricing.legacy import legacy_price_table
from app.pricing.tiers import tier_cards


def render_pricing(flags: Flags, currency: str, region: str) -> str:
    if flags.enabled(Flag.NEW_PRICING):
        body = tier_cards(currency, region)
    else:
        body = legacy_price_table(currency)
    return (
        "<html><body><h1>Pricing</h1>"
        + body
        + f"<script>window.FLAGS = {json.dumps(flags.for_client())};</script>"
        + '<script src="/static/pricing.js"></script>'
        + "</body></html>"
    )
