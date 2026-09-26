import sqlite3

SCHEMA = """
CREATE TABLE IF NOT EXISTS wallets (
  customer_id TEXT PRIMARY KEY,
  balance_paise INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS processed_events (
  event_id TEXT PRIMARY KEY,
  processed_at TEXT NOT NULL DEFAULT (datetime('now'))
);
"""


def connect(path):
    conn = sqlite3.connect(path, check_same_thread=False)
    conn.executescript(SCHEMA)
    return conn
