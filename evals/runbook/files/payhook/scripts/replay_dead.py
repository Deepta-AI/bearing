"""Move dead events back to pending so the worker tries them again (attempts
reset to 0). With no filter it replays every dead event.

    python3 scripts/replay_dead.py --error signature_invalid --dry-run
    python3 scripts/replay_dead.py --error orders_api_503 --limit 500
"""

import argparse
import sys

from app import db


def replay(conn, error=None, limit=None, dry_run=False):
    sql = "SELECT id FROM events WHERE status = 'dead'"
    args = []
    if error:
        sql += " AND last_error = ?"
        args.append(error)
    sql += " ORDER BY received_at"
    if limit:
        sql += " LIMIT ?"
        args.append(limit)
    ids = [r[0] for r in conn.execute(sql, args).fetchall()]
    if not dry_run:
        for event_id in ids:
            conn.execute(
                "UPDATE events SET status = 'pending', attempts = 0, claimed_at = NULL WHERE id = ?",
                (event_id,),
            )
        conn.commit()
    return len(ids)


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--error", help="only events whose last_error equals this")
    p.add_argument("--limit", type=int, help="replay at most this many, oldest first")
    p.add_argument("--dry-run", action="store_true", help="count, change nothing")
    a = p.parse_args(argv)
    n = replay(db.connect(), a.error, a.limit, a.dry_run)
    print(f"{'would replay' if a.dry_run else 'replayed'} {n} events")
    return 0


if __name__ == "__main__":
    sys.exit(main())
