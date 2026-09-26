"""Money is held as integer minor units (paise) to avoid float drift."""

type Paise = int


def parse_amount(text: str) -> Paise:
    """Parse "1234.50" into 123450 paise. Rejects more than two decimals."""
    text = text.strip()
    negative = text.startswith("-")
    if negative:
        text = text[1:]
    whole, _, frac = text.partition(".")
    if not whole.isdigit() or (frac and not frac.isdigit()) or len(frac) > 2:
        raise ValueError(f"not an amount: {text!r}")
    value = int(whole) * 100 + int(frac.ljust(2, "0") or "0")
    return -value if negative else value


def format_amount(value: Paise) -> str:
    sign = "-" if value < 0 else ""
    value = abs(value)
    return f"{sign}{value // 100}.{value % 100:02d}"
