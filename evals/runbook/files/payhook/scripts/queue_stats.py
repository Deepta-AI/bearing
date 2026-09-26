"""Print queue depth, the oldest pending event's age, claims in progress and,
with --by-error, dead letters grouped by last_error. Reads DATABASE_URL from
the environment (inside a payhook pod it is already set from the secret)."""

import argparse
import json
import sys

from app import db, queue


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--by-error", action="store_true", help="group dead letters by last_error")
    a = p.parse_args(argv)
    s = queue.stats(db.connect())
    if not a.by_error:
        s.pop("dead_by_error")
    json.dump(s, sys.stdout, indent=2, sort_keys=True)
    print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
