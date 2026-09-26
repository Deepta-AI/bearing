"""Delete every pending event. For resetting staging only: in production a
deleted event is a payment that is never applied to its order, and the
provider does not resend it."""

import argparse
import sys

from app import db


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--yes", action="store_true", help="confirm")
    a = p.parse_args(argv)
    if not a.yes:
        print("refusing without --yes")
        return 1
    conn = db.connect()
    n = conn.execute("DELETE FROM events WHERE status = 'pending'").rowcount
    conn.commit()
    print(f"deleted {n} pending events")
    return 0


if __name__ == "__main__":
    sys.exit(main())
