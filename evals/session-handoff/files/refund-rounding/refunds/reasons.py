"""Reason codes a support agent picks when issuing a refund (PAY-139)."""

REASONS = {
    "DAMAGED": "Item arrived damaged",
    "LATE": "Delivered after the promised date",
    "WRONG_ITEM": "Wrong item shipped",
    "GOODWILL": "Goodwill gesture",
}


def describe(code: str) -> str:
    try:
        return REASONS[code]
    except KeyError:
        raise ValueError(f"unknown refund reason {code!r}") from None
