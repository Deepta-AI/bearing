"""Weekly: invite customers who closed their account recently to come back
(deploy/cron.yaml). Marketing asked for this in the spring campaign."""

import logging
import sys

from app.db import connect
from app.newsletter import MailBlastClient

log = logging.getLogger("mealbox.jobs.winback")

WINBACK_DAYS = 60


def lapsed(db, days=WINBACK_DAYS):
    return db.execute(
        "SELECT email, name FROM users"
        " WHERE deleted_at IS NOT NULL AND deleted_at >= datetime('now', ?)",
        (f"-{days} days",),
    ).fetchall()


def run(db, client):
    rows = lapsed(db)
    for row in rows:
        client.upsert_contact(row["email"], row["name"])
    log.info("winback: invited %d lapsed customers", len(rows))
    return len(rows)


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    run(connect(sys.argv[1] if len(sys.argv) > 1 else "mealbox.db"), MailBlastClient())
