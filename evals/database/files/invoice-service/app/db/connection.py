"""Opens the Postgres connection. psycopg is imported here only, so the
unit tests (which use tests/fakes.py) need no driver installed."""

import os


def connect(url=None):
    import psycopg  # noqa: PLC0415

    return psycopg.connect(url or os.environ["DATABASE_URL"])
