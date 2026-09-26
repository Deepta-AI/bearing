import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app import db, settings


def purge(conn, ttl_hours=settings.DEDUPE_TTL_HOURS):
    cur = conn.execute(
        "DELETE FROM processed_events WHERE processed_at < datetime('now', ?)",
        (f"-{ttl_hours} hours",),
    )
    conn.commit()
    return cur.rowcount


if __name__ == "__main__":
    n = purge(db.connect(settings.DB_PATH))
    print(f"purged {n} processed events")
