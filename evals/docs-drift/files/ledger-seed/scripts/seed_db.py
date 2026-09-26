"""Load demo rows into the local ledger file.

Renamed from scripts/seed.py on this branch; the row count moved from a
command line flag to SEED_ROWS so CI and the Makefile set it the same way.
"""

import json
import os

DB = os.environ.get("LEDGER_DB", "ledger.jsonl")
ROWS = int(os.environ.get("SEED_ROWS", "100"))


def main():
    with open(DB, "a", encoding="utf-8") as f:
        for i in range(ROWS):
            f.write(json.dumps({"cents": i * 100}) + "\n")
    print(f"seeded {ROWS} rows into {DB}")


if __name__ == "__main__":
    main()
