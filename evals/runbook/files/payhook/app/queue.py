"""The events table used as a queue.

status: pending -> in_progress (claimed) -> done | pending (retry) | dead.
A claim whose worker died is taken again once LEASE_SECONDS have passed.
"""

import time

from app import config


def enqueue(conn, provider_event_id, kind, payload, now=None):
    now = now or time.time()
    conn.execute(
        "INSERT INTO events (provider_event_id, kind, payload, received_at) "
        "VALUES (?, ?, ?, ?) ON CONFLICT (provider_event_id) DO NOTHING",
        (provider_event_id, kind, payload, now),
    )
    conn.commit()


def claim_batch(conn, now=None, size=None):
    """Claim up to `size` events: pending ones, and in_progress ones whose
    lease expired. Returns the claimed rows as (id, kind, payload, attempts)."""
    now = now or time.time()
    size = size or config.BATCH_SIZE
    expired = now - config.LEASE_SECONDS
    rows = conn.execute(
        "SELECT id FROM events WHERE status = 'pending' "
        "OR (status = 'in_progress' AND claimed_at < ?) "
        "ORDER BY received_at LIMIT ?",
        (expired, size),
    ).fetchall()
    ids = [r[0] for r in rows]
    claimed = []
    for event_id in ids:
        cur = conn.execute(
            "UPDATE events SET status = 'in_progress', claimed_at = ?, attempts = attempts + 1 "
            "WHERE id = ? AND (status = 'pending' OR (status = 'in_progress' AND claimed_at < ?))",
            (now, event_id, expired),
        )
        if cur.rowcount == 1:
            claimed.append(event_id)
    conn.commit()
    if not claimed:
        return []
    marks = ",".join("?" * len(claimed))
    return conn.execute(
        f"SELECT id, kind, payload, attempts FROM events WHERE id IN ({marks}) ORDER BY received_at",
        claimed,
    ).fetchall()


def mark_done(conn, event_id):
    conn.execute("UPDATE events SET status = 'done', last_error = NULL WHERE id = ?", (event_id,))
    conn.commit()


def mark_failed(conn, event_id, attempts, error_kind):
    """Back to pending for another attempt, or dead after MAX_ATTEMPTS."""
    status = "dead" if attempts >= config.MAX_ATTEMPTS else "pending"
    conn.execute(
        "UPDATE events SET status = ?, last_error = ? WHERE id = ?",
        (status, error_kind, event_id),
    )
    conn.commit()
    return status


def stats(conn, now=None):
    now = now or time.time()
    pending, oldest = conn.execute(
        "SELECT COUNT(*), MIN(received_at) FROM events WHERE status = 'pending'"
    ).fetchone()
    in_progress = conn.execute(
        "SELECT COUNT(*) FROM events WHERE status = 'in_progress'"
    ).fetchone()[0]
    dead = dict(
        conn.execute(
            "SELECT last_error, COUNT(*) FROM events WHERE status = 'dead' GROUP BY last_error"
        ).fetchall()
    )
    return {
        "pending": pending,
        "oldest_pending_seconds": round(now - oldest, 1) if oldest else 0.0,
        "in_progress": in_progress,
        "dead_by_error": dead,
    }
