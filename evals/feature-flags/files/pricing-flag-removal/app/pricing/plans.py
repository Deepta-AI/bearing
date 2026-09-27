from decimal import Decimal

PLANS = [
    {"id": "starter", "name": "Starter", "monthly": Decimal("9.00")},
    {"id": "team", "name": "Team", "monthly": Decimal("29.00")},
    {"id": "business", "name": "Business", "monthly": Decimal("79.00")},
]

VAT = {"eu": Decimal("0.20"), "us": Decimal("0")}
