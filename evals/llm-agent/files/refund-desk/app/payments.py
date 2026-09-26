"""Refunds through the payment gateway.

A refund moves money out of our account and cannot be reversed. The gateway
deduplicates on idempotency_key for 48 hours when one is sent; with no key,
every call creates a new refund.
"""

from datetime import datetime, timezone
from typing import Protocol

from app.store import Refund, Store


class GatewayError(Exception):
    """Timeout or 5xx. The refund may or may not have been created."""


class Gateway(Protocol):
    def create_refund(self, order_id: str, amount_paise: int, idempotency_key: str | None) -> dict:
        """Returns {"id": "rf_...", "status": "succeeded" | "failed"}; raises GatewayError."""
        ...


class Payments:
    def __init__(self, store: Store, gateway: Gateway):
        self.store = store
        self.gateway = gateway

    def refund(self, order_id: str, amount_paise: int, idempotency_key: str | None = None) -> dict:
        result = self.gateway.create_refund(order_id, amount_paise, idempotency_key)
        if result.get("status") == "succeeded":
            self.store.add_refund(Refund(order_id, amount_paise, result["id"],
                                         datetime.now(timezone.utc).isoformat(timespec="seconds")))
        return result
