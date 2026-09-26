"""The payment_attempts table: one row per charge attempt, captured or declined."""

import sqlite3

SCHEMA = """
CREATE TABLE IF NOT EXISTS payment_attempts (
    id INTEGER PRIMARY KEY,
    order_id TEXT NOT NULL,
    amount_paise INTEGER NOT NULL,
    flow TEXT NOT NULL,              -- 'classic' or '3ds_v2'
    status TEXT NOT NULL,            -- 'captured' or 'declined'
    decline_code TEXT,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);
CREATE INDEX IF NOT EXISTS payment_attempts_created ON payment_attempts (created_at);
"""


def connect(path: str = ":memory:") -> sqlite3.Connection:
    conn = sqlite3.connect(path)
    conn.executescript(SCHEMA)
    return conn


def record_attempt(conn, order_id, amount_paise, flow, status, decline_code=None):
    conn.execute(
        "INSERT INTO payment_attempts (order_id, amount_paise, flow, status, decline_code)"
        " VALUES (?, ?, ?, ?, ?)",
        (order_id, amount_paise, flow, status, decline_code),
    )
    conn.commit()
