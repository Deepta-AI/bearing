"""Applies provider events to invoices, each event id exactly once."""

import sqlite3
from datetime import UTC, datetime

from app.db import Database
from app.webhooks.schemas import ProviderEvent


def _claim_event(conn: sqlite3.Connection, event: ProviderEvent) -> bool:
    """Record the event id; False when it was already applied."""
    cur = conn.execute(
        "INSERT OR IGNORE INTO processed_events (event_id, type, received_at) VALUES (?, ?, ?)",
        (event.id, event.type, datetime.now(UTC).isoformat()),
    )
    return cur.rowcount == 1


async def apply_payment(db: Database, event: ProviderEvent) -> str:
    """Add a successful payment to its invoice; 'duplicate' when seen before."""

    def work(conn: sqlite3.Connection) -> str:
        if not _claim_event(conn, event):
            return "duplicate"
        cur = conn.execute(
            """
            UPDATE invoices
               SET amount_paid_minor = amount_paid_minor + ?,
                   status = CASE WHEN amount_paid_minor + ? >= amount_minor
                                 THEN 'paid' ELSE status END
             WHERE id = ? AND currency = ? AND status IN ('open', 'paid')
            """,
            (event.data.amount_minor, event.data.amount_minor, event.data.invoice_id,
             event.data.currency),
        )
        return "applied" if cur.rowcount == 1 else "unmatched"

    return await db.transaction(work)
