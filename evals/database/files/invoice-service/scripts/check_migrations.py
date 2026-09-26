#!/usr/bin/env python3
"""Lint goose migrations: names, numbering, an Up and a non-empty Down,
NO TRANSACTION around CONCURRENTLY, lock_timeout before ALTER TABLE.

Prints the number of files checked; fails when there are none.
"""

import os
import re
import sys

NAME = re.compile(r"^(\d{4})_[a-z0-9_]+\.sql$")


def check(path, problems):
    text = open(path, encoding="utf-8").read()
    base = os.path.basename(path)
    if "-- +goose Up" not in text or "-- +goose Down" not in text:
        problems.append(f"{base}: needs both -- +goose Up and -- +goose Down")
        return
    up, down = text.split("-- +goose Down", 1)
    if not [l for l in down.splitlines() if l.strip() and not l.strip().startswith("--")]:
        problems.append(f"{base}: empty Down")
    if "CONCURRENTLY" in text.upper() and "-- +goose NO TRANSACTION" not in text:
        problems.append(f"{base}: CONCURRENTLY needs -- +goose NO TRANSACTION")
    if re.search(r"\bALTER\s+TABLE\b", up, re.I) and "lock_timeout" not in up:
        problems.append(f"{base}: ALTER TABLE in the Up without SET lock_timeout")


def main():
    d = sys.argv[1] if len(sys.argv) > 1 else "db/migrations"
    files = sorted(f for f in os.listdir(d) if f.endswith(".sql"))
    problems = []
    expected = 1
    for f in files:
        m = NAME.match(f)
        if not m:
            problems.append(f"{f}: name is not NNNN_snake_case.sql")
            continue
        if int(m.group(1)) != expected:
            problems.append(f"{f}: expected number {expected:04d}")
        expected = int(m.group(1)) + 1
        check(os.path.join(d, f), problems)
    for p in problems:
        print(f"problem: {p}")
    if not files:
        print("check-migrations: 0 files, nothing checked", file=sys.stderr)
        return 1
    print(f"check-migrations: {len(files)} files, {len(problems)} problems")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
