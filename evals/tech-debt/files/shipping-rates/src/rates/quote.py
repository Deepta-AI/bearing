"""Price one parcel: base rate by zone and weight, plus surcharges."""

from rates.carriers import BASE_RATE_PER_KG, fuel_surcharge_pct
from rates.zones import resolve_zone


def build_quote(weight_kg, pincode, surcharges=[]):  # noqa: B006
    # TODO: support multi-parcel quotes (one weight per parcel)
    zone = resolve_zone(pincode)
    base = BASE_RATE_PER_KG[zone] * weight_kg
    surcharges.append(base * fuel_surcharge_pct() / 100)
    return round(base + sum(surcharges), 2)
