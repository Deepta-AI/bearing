"""Accounts and balanced postings, stored in memory or in Postgres."""

import os
from dataclasses import dataclass, field

from ledger.money import Paise


class UnbalancedPosting(ValueError):
    pass


@dataclass
class Posting:
    reference: str
    lines: list[tuple[str, Paise]] = field(default_factory=list)

    def check(self) -> None:
        if len(self.lines) < 2:
            raise UnbalancedPosting(f"{self.reference}: a posting needs two lines")
        total = sum(amount for _, amount in self.lines)
        if total != 0:
            raise UnbalancedPosting(f"{self.reference}: lines sum to {total}, not 0")


class MemoryLedger:
    def __init__(self) -> None:
        self.balances: dict[str, Paise] = {}
        self.references: set[str] = set()

    def open(self, account: str) -> None:
        self.balances.setdefault(account, 0)

    def post(self, posting: Posting) -> bool:
        """Apply a posting once; a repeated reference is ignored and returns False."""
        posting.check()
        if posting.reference in self.references:
            return False
        for account, _ in posting.lines:
            if account not in self.balances:
                raise KeyError(f"unknown account {account}")
        for account, amount in posting.lines:
            self.balances[account] += amount
        self.references.add(posting.reference)
        return True

    def balance(self, account: str) -> Paise:
        return self.balances[account]


class PostgresLedger:
    def __init__(self, dsn: str) -> None:
        import psycopg

        self.conn = psycopg.connect(dsn, autocommit=False)

    def open(self, account: str) -> None:
        with self.conn.transaction():
            self.conn.execute(
                "INSERT INTO accounts (name) VALUES (%s) ON CONFLICT DO NOTHING", (account,)
            )

    def post(self, posting: Posting) -> bool:
        posting.check()
        with self.conn.transaction():
            cur = self.conn.execute(
                "INSERT INTO postings (reference) VALUES (%s) ON CONFLICT DO NOTHING RETURNING id",
                (posting.reference,),
            )
            row = cur.fetchone()
            if row is None:
                return False
            for account, amount in posting.lines:
                self.conn.execute(
                    "INSERT INTO posting_lines (posting_id, account, amount) VALUES (%s, %s, %s)",
                    (row[0], account, amount),
                )
        return True

    def balance(self, account: str) -> Paise:
        cur = self.conn.execute(
            "SELECT COALESCE(SUM(amount), 0) FROM posting_lines WHERE account = %s", (account,)
        )
        return cur.fetchone()[0]
