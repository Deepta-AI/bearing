"""Export one hour of events to CSV."""

import csv
import os
from contextlib import closing

from export.accounts import account_region
from export.db import connect

COLUMNS = ["event_id", "account_id", "region", "kind", "created_at", "payload"]

# Event ids already written. Events are delivered at least once, so the
# same id can appear more than once; each is exported once.
_exported_ids = set()


def output_path(out_dir, hour):
    return os.path.join(out_dir, f"events-{hour}.csv")


def export_hour(db_path, hour, out_dir):
    """Write OUTPUT_DIR/events-<hour>.csv and return the number of rows."""
    with closing(connect(db_path)) as conn:
        rows = conn.execute(
            "SELECT event_id, account_id, kind, created_at, payload FROM events "
            "WHERE hour = ? ORDER BY created_at, event_id",
            (hour,),
        ).fetchall()

    out = []
    for event_id, account_id, kind, created_at, payload in rows:
        if event_id in _exported_ids:
            continue
        _exported_ids.add(event_id)
        out.append(
            [event_id, account_id, account_region(db_path, account_id), kind, created_at, payload]
        )

    path = output_path(out_dir, hour)
    tmp = path + ".tmp"
    with open(tmp, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(COLUMNS)
        w.writerows(out)
    os.replace(tmp, path)
    return len(out)
