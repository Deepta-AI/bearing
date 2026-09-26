"""Database connection. Production is Postgres (psycopg, installed in the
image); tests and local runs use sqlite. The SQL in app/queue.py is written to
run on both."""

import sqlite3

from app import config

SCHEMA = """
CREATE TABLE IF NOT EXISTS events (
    id INTEGER PRIMARY KEY,
    provider_event_id TEXT NOT NULL UNIQUE,
    kind TEXT NOT NULL,
    payload TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    attempts INTEGER NOT NULL DEFAULT 0,
    last_error TEXT,
    received_at REAL NOT NULL,
    claimed_at REAL
);
"""


def connect(url=None):
    url = url or config.DATABASE_URL
    if url.startswith("sqlite://"):
        conn = sqlite3.connect(url[len("sqlite:///"):] or ":memory:")
        conn.executescript(SCHEMA)
        return conn
    import psycopg  # production image only

    return psycopg.connect(url)
