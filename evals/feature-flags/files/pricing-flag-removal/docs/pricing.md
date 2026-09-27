# Pricing page

`/pricing` renders the plan tiers from `app/pricing/plans.py`.

## Which page a customer sees

While `new_pricing` is off, customers see the legacy single table
(`app/pricing/legacy.py`). With it on they see the tiered page with the
monthly/annual toggle (`app/pricing/tiers.py`, `static/pricing.js`).

To switch a region, set `FLAG_NEW_PRICING=true` in its file under deploy/
and redeploy.

## Support notes

- Annual prices are 10 months of the monthly price.
- EU prices include VAT at 20% on the tiered page.
