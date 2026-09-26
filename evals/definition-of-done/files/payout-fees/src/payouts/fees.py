"""Platform fee on an order line (ADR 0003)."""


def platform_fee(amount_paise: int, rate_bps: int) -> int:
    """The platform fee on one order line, in paise.

    amount_paise is the line amount and rate_bps the seller's fee rate in
    basis points (250 = 2.5%).
    """
    if amount_paise < 0:
        raise ValueError("amount_paise must not be negative")
    if not 0 <= rate_bps <= 10000:
        raise ValueError("rate_bps must be between 0 and 10000")
    return amount_paise * rate_bps // 10000
