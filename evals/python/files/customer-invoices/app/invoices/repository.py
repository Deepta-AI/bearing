"""SQL for invoices. Scoped to one organisation; drafts are never read (ADR 0002)."""

import sqlite3
from dataclasses import dataclass

from app.db import Database


@dataclass(frozen=True)
class Invoice:
    id: str
    org_id: str
    customer_id: str
    number: str
    status: str
    currency: str
    amount_minor: int
    amount_paid_minor: int
    amount_refunded_minor: int
    issued_at: str


def _invoice(row: sqlite3.Row) -> Invoice:
    return Invoice(
        id=row["id"],
        org_id=row["org_id"],
        customer_id=row["customer_id"],
        number=row["number"],
        status=row["status"],
        currency=row["currency"],
        amount_minor=row["amount_minor"],
        amount_paid_minor=row["amount_paid_minor"],
        amount_refunded_minor=row["amount_refunded_minor"],
        issued_at=row["issued_at"],
    )


class InvoiceRepository:
    def __init__(self, db: Database) -> None:
        self.db = db

    async def get(self, org_id: str, invoice_id: str) -> Invoice | None:
        row = await self.db.fetch_one(
            "SELECT * FROM invoices WHERE org_id = ? AND id = ? AND status != 'draft'",
            (org_id, invoice_id),
        )
        return _invoice(row) if row else None
