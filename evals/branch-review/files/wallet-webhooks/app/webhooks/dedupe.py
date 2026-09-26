def seen(conn, event_id):
    row = conn.execute(
        "SELECT 1 FROM processed_events WHERE event_id = ?", (event_id,)
    ).fetchone()
    return row is not None


def mark(conn, event_id):
    conn.execute("INSERT OR IGNORE INTO processed_events (event_id) VALUES (?)", (event_id,))
