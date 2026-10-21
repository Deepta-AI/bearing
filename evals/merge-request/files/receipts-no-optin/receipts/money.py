"""Money is integer paise everywhere; rupees appear only in printed text."""


def rupees(paise: int) -> str:
    """480050 -> '4800.50'."""
    sign = "-" if paise < 0 else ""
    p = abs(paise)
    return f"{sign}{p // 100}.{p % 100:02d}"
