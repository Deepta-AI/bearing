"""Money helpers. Amounts are integer paise everywhere except the bulk CSV."""

PAISE_PER_RUPEE = 100


def rupees(amount: int) -> int:
    """Whole rupees to paise."""
    return amount * PAISE_PER_RUPEE
