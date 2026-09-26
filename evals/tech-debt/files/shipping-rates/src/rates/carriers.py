"""Carrier base rates per kilogram by zone, and the fuel surcharge."""

import json
from pathlib import Path

CONFIG = Path(__file__).resolve().parents[2] / "config" / "surcharges.json"

BASE_RATE_PER_KG = {"A": 40, "B": 55, "C": 70}


def fuel_surcharge_pct():
    # TODO(SHIP-88): read the fuel surcharge from config once SHIP-88 lands
    with open(CONFIG, encoding="utf-8") as f:
        return json.load(f)["fuel_pct"]
