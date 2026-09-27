import sqlite3

SCHEMA = """
CREATE TABLE IF NOT EXISTS accounts (
    account_id TEXT PRIMARY KEY,
    region     TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS events (
    rowid_     INTEGER PRIMARY KEY,
    event_id   TEXT NOT NULL,
    account_id TEXT NOT NULL,
    kind       TEXT NOT NULL,
    created_at TEXT NOT NULL,
    hour       TEXT NOT NULL,
    payload    TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS events_hour ON events (hour);
"""


def connect(path):
    conn = sqlite3.connect(path)
    conn.executescript(SCHEMA)
    return conn
