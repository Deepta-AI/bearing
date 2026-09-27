"""SQLite access. sqlite3 blocks, so every call runs in the threadpool (ADR 0001)."""

import sqlite3
from collections.abc import Callable, Sequence
from contextlib import closing
from typing import TypeVar

from fastapi import Request
from fastapi.concurrency import run_in_threadpool

T = TypeVar("T")
Params = Sequence[object] | dict[str, object]


class Database:
    """One connection per call, opened and closed in a worker thread."""

    def __init__(self, path: str) -> None:
        self.path = path

    def connect(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.path, timeout=5)
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA foreign_keys = ON")
        return conn

    def _fetch_all(self, sql: str, params: Params) -> list[sqlite3.Row]:
        with closing(self.connect()) as conn:
            return conn.execute(sql, params).fetchall()

    def _fetch_one(self, sql: str, params: Params) -> sqlite3.Row | None:
        with closing(self.connect()) as conn:
            row: sqlite3.Row | None = conn.execute(sql, params).fetchone()
            return row

    def _transaction(self, work: Callable[[sqlite3.Connection], T]) -> T:
        with closing(self.connect()) as conn:
            conn.execute("BEGIN IMMEDIATE")
            try:
                result = work(conn)
            except BaseException:
                conn.rollback()
                raise
            conn.commit()
            return result

    async def fetch_all(self, sql: str, params: Params = ()) -> list[sqlite3.Row]:
        return await run_in_threadpool(self._fetch_all, sql, params)

    async def fetch_one(self, sql: str, params: Params = ()) -> sqlite3.Row | None:
        return await run_in_threadpool(self._fetch_one, sql, params)

    async def transaction(self, work: Callable[[sqlite3.Connection], T]) -> T:
        """Run work(conn) in one write transaction; roll back if it raises."""
        return await run_in_threadpool(self._transaction, work)


def get_db(request: Request) -> Database:
    """The Database created in the lifespan."""
    db: Database = request.app.state.db
    return db
