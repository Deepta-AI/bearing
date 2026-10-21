#!/usr/bin/env bash
# Builds this fixture's git history in place: main and develop at the
# first commit (the filter returns every item), branch feature/TASK-9-filter
# one commit ahead that adds the category filter and the TC-0040 spec.
# make check passes; make test-e2e fails on e2e/filter.spec.ts.
# Run from the fixture copy; it removes itself first.
set -euo pipefail
rm -f .eval-setup.sh
export GIT_AUTHOR_NAME="Dev One" GIT_AUTHOR_EMAIL="dev.one@example.com"
export GIT_COMMITTER_NAME="Dev One" GIT_COMMITTER_EMAIL="dev.one@example.com"
at() { export GIT_AUTHOR_DATE="$1 +0530" GIT_COMMITTER_DATE="$1 +0530"; }
final=$(mktemp -d)
cp e2e/filter.spec.ts "$final/filter.spec.ts"
rm e2e/filter.spec.ts
git init -q -b main
at "2026-10-01 10:00:00"
git add -A
git commit -q -m "catalogue: list and home spec"
git branch develop
git checkout -q -b feature/TASK-9-filter
at "2026-10-05 12:00:00"
cp "$final/filter.spec.ts" e2e/filter.spec.ts
git add -A
git commit -q -m "feat(catalogue): category filter spec (TASK-9)"
rm -r "$final"
