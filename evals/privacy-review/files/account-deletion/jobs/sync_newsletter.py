"""Nightly: push every opted-in user to MailBlast (deploy/cron.yaml)."""

import logging
import sys

from app.db import connect
from app.newsletter import MailBlastClient

log = logging.getLogger("mealbox.jobs.sync_newsletter")


def sync(db, client):
    rows = db.execute(
        "SELECT email, name FROM users WHERE marketing_opt_in = 1"
    ).fetchall()
    for row in rows:
        client.upsert_contact(row["email"], row["name"])
    log.info("synced %d contacts", len(rows))
    return len(rows)


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    sync(connect(sys.argv[1] if len(sys.argv) > 1 else "mealbox.db"), MailBlastClient())
