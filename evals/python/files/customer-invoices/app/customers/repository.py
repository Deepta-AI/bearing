"""SQL for customers. Every query is scoped to one organisation."""

import sqlite3
from dataclasses import dataclass

from app.db import Database


@dataclass(frozen=True)
class Customer:
    id: str
    org_id: str
    name: str
    email: str
    created_at: str


def _customer(row: sqlite3.Row) -> Customer:
    return Customer(
        id=row["id"],
        org_id=row["org_id"],
        name=row["name"],
        email=row["email"],
        created_at=row["created_at"],
    )


class CustomerRepository:
    def __init__(self, db: Database) -> None:
        self.db = db

    async def get(self, org_id: str, customer_id: str) -> Customer | None:
        row = await self.db.fetch_one(
            "SELECT * FROM customers WHERE org_id = ? AND id = ?", (org_id, customer_id)
        )
        return _customer(row) if row else None

    async def list_newest_first(
        self, org_id: str, limit: int, after: tuple[str, str] | None
    ) -> list[Customer]:
        """Up to limit customers, newest first, strictly after the cursor row."""
        sql = "SELECT * FROM customers WHERE org_id = ?"
        params: list[object] = [org_id]
        if after is not None:
            sql += " AND (created_at, id) < (?, ?)"
            params += [after[0], after[1]]
        sql += " ORDER BY created_at DESC, id DESC LIMIT ?"
        params.append(limit)
        return [_customer(r) for r in await self.db.fetch_all(sql, params)]
