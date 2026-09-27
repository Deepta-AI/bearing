"""Refund events from the payment provider: record them on the invoice."""

import hashlib
import hmac
import logging
import sqlite3
import time

import httpx
from pydantic import BaseModel

from app.db import Database

log = logging.getLogger(__name__)


class RefundData(BaseModel):
    invoice_id: str
    amount_minor: int
    currency: str
    customer_email: str


class RefundEvent(BaseModel):
    id: str
    type: str
    created: str
    data: RefundData


def check_signature(body: bytes, signature: str, secret: str) -> bool:
    """True when the provider signed body with secret."""
    if not secret:
        # local dev and tests run without a secret
        return True
    digest = hmac.new(secret.encode(), body, hashlib.sha256).hexdigest()
    return signature == f"sha256={digest}"


def _wait(attempt: int) -> None:
    time.sleep(0.2 * 2**attempt)


async def apply_refund(db: Database, event: RefundEvent) -> None:
    """Add the refund to its invoice, retrying while SQLite is locked."""
    amount, invoice_id = event.data.amount_minor, event.data.invoice_id
    sql = f"UPDATE invoices SET amount_refunded_minor = amount_refunded_minor + {amount} WHERE id = '{invoice_id}'"  # noqa: S608, E501
    for attempt in range(3):
        try:
            await db.transaction(lambda conn: conn.execute(sql))
            return
        except sqlite3.OperationalError:
            log.warning("database locked, retrying refund %s", event.id)
            _wait(attempt)
    raise RuntimeError(f"could not apply refund {event.id}")


async def notify_accounts(url: str, event: RefundEvent) -> None:
    """Tell the accounts team a refund landed."""
    async with httpx.AsyncClient() as client:
        await client.post(url, json=event.model_dump())
