"""A scripted stand-in for a psycopg connection: records every statement
and answers from a queue of results the test supplies."""

from contextlib import contextmanager


class FakeCursor:
    def __init__(self, rows):
        self.rows = rows

    def fetchone(self):
        return self.rows[0] if self.rows else None

    def fetchall(self):
        return list(self.rows)


class FakeConn:
    def __init__(self, results=None):
        self.results = list(results or [])
        self.executed = []
        self.transactions = 0

    def execute(self, sql, params=()):
        self.executed.append((sql, params))
        nxt = self.results.pop(0) if self.results else []
        if isinstance(nxt, Exception):
            raise nxt
        return FakeCursor(nxt)

    @contextmanager
    def transaction(self):
        self.transactions += 1
        yield
