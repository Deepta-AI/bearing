"""Refunds against the card gateway."""

import time

from .config import load_settings
from .gateway import GatewayTimeout


class RefundFailed(Exception):
    """Every attempt timed out; the refund may still need a manual check."""


def refund(gateway, order_id, amount_paise, *, settings=None, sleep=time.sleep):
    if amount_paise <= 0:
        raise ValueError("refund amount must be positive")
    settings = settings or load_settings()
    key = f"refund:{order_id}"
    attempt = 0
    while True:
        attempt += 1
        try:
            return gateway.refund(order_id, amount_paise, idempotency_key=key)
        except GatewayTimeout as e:
            if attempt >= settings.refund_max_attempts:
                raise RefundFailed(f"{order_id}: {attempt} attempts timed out") from e
            sleep(settings.refund_backoff_ms * 2 ** (attempt - 1) / 1000)
