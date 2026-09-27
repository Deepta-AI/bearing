#!/usr/bin/env bash
# Builds this fixture's history in place: main (two commits, mirrored as
# origin/main) and the checked-out branch feature/DATA-42-seed-rename, which
# renames the seed script and its make target. The files in the fixture are
# the branch state; main's versions are written here first. Run from the
# fixture copy; it removes itself first.
set -euo pipefail
rm -f .eval-setup.sh .eval-branch
export GIT_AUTHOR_NAME="Dev One" GIT_AUTHOR_EMAIL="dev.one@example.com"
export GIT_COMMITTER_NAME="Dev One" GIT_COMMITTER_EMAIL="dev.one@example.com"
at() { export GIT_AUTHOR_DATE="$1 +0530" GIT_COMMITTER_DATE="$1 +0530"; }

keep="$(mktemp -d)"
cp Makefile scripts/seed_db.py docs/runbooks/database.md docs/postmortems/2026-08-14-seed-on-staging.md "$keep/"
rm -f scripts/seed_db.py docs/postmortems/2026-08-14-seed-on-staging.md

cat > Makefile <<'MK'
.PHONY: test check seed db-reset
test: ## Unit tests
	python3 -m unittest discover -s tests

check: test ## The gate
	@echo "check: passed"

seed: ## Load 100 demo rows into LEDGER_DB
	python3 scripts/seed.py

db-reset: ## Delete the local ledger file
	rm -f "$${LEDGER_DB:-ledger.jsonl}"
MK
cat > scripts/seed.py <<'PY'
"""Load demo rows into the local ledger file.

Usage: python3 scripts/seed.py [--rows N]   (default 100)
"""

import argparse
import json
import os
import sys

DB = os.environ.get("LEDGER_DB", "ledger.jsonl")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--rows", type=int, default=100)
    rows = ap.parse_args().rows
    here = os.path.realpath(os.getcwd())
    path = os.path.realpath(DB)
    if os.path.commonpath([here, path]) != here:
        sys.exit(f"seed: refusing to write outside {here}: {path}")
    with open(DB, "a", encoding="utf-8") as f:
        for i in range(rows):
            f.write(json.dumps({"cents": i * 100}) + "\n")
    print(f"seeded {rows} rows into {DB}")


if __name__ == "__main__":
    main()
PY
cat > docs/runbooks/database.md <<'MD'
# Runbook: local and staging database

Owner: platform rotation. Last reviewed 2026-08-02.

## Seed demo data

1. `make seed` loads 100 demo rows into `ledger.jsonl`.
2. For a different count run `python3 scripts/seed.py --rows 500`.
3. Check: the command prints `seeded 100 rows into ledger.jsonl`.

## Reset

`make db-reset` deletes the file; seed again afterwards.

## Rollback

Seeding only inserts; a reset and a fresh seed is the rollback.
MD

git init -q -b main
git remote add origin git@code.example.internal:finance/ledger.git
git add -A
at "2026-08-02T10:00:00"; git commit -q -m "feat(ledger): balances, seed script and runbook [DATA-7]"

cp "$keep/2026-08-14-seed-on-staging.md" docs/postmortems/
cp "$keep/database.md" docs/runbooks/database.md
git add -A
at "2026-08-20T16:30:00"; git commit -q -m "fix(seed): refuse paths outside the repo; postmortem and runbook [DATA-31]"
git update-ref refs/remotes/origin/main main
git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main

git checkout -q -b feature/DATA-42-seed-rename
git mv scripts/seed.py scripts/seed_db.py
cp "$keep/seed_db.py" scripts/seed_db.py
cp "$keep/Makefile" Makefile
git add -A
at "2026-09-24T11:15:00"; git commit -q -m "refactor(seed): seed.py -> seed_db.py, make seed -> make db-seed, SEED_ROWS [DATA-42]"
rm -rf "$keep"
