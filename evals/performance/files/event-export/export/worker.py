"""Every pass, export each of the last 24 hours whose file is missing."""

import logging
import os
import time
from datetime import datetime, timedelta, timezone

from export.job import export_hour, output_path

log = logging.getLogger("event-export")


def hours_to_check(now):
    top = now.replace(minute=0, second=0, microsecond=0)
    # The current hour is still filling; start with the one before it.
    return [(top - timedelta(hours=h)).strftime("%Y-%m-%dT%H") for h in range(1, 25)]


def run_pass(db_path, out_dir, now):
    written = 0
    for hour in hours_to_check(now):
        if os.path.exists(output_path(out_dir, hour)):
            continue
        n = export_hour(db_path, hour, out_dir)
        log.info("exported %s: %d rows", hour, n)
        written += 1
    return written


def main():
    logging.basicConfig(level=logging.INFO)
    db_path = os.environ.get("EVENTS_DB", "events.db")
    out_dir = os.environ.get("OUTPUT_DIR", "exports")
    interval = int(os.environ.get("PASS_INTERVAL_SECONDS", "600"))
    os.makedirs(out_dir, exist_ok=True)
    while True:
        run_pass(db_path, out_dir, datetime.now(timezone.utc))
        time.sleep(interval)


if __name__ == "__main__":
    main()
