"""Apply migrations/*.sql in name order to DATABASE_URL (postgresql://...)."""

import os
import pathlib
import sys


def main() -> int:
    dsn = os.environ.get("DATABASE_URL")
    if not dsn:
        print("migrate: DATABASE_URL is not set", file=sys.stderr)
        return 1
    import psycopg

    files = sorted(pathlib.Path(__file__).resolve().parent.parent.glob("migrations/*.sql"))
    if not files:
        print("migrate: 0 migration files found", file=sys.stderr)
        return 1
    with psycopg.connect(dsn) as conn:
        for path in files:
            conn.execute(path.read_text())
    print(f"migrate: {len(files)} files applied")
    return 0


if __name__ == "__main__":
    sys.exit(main())
