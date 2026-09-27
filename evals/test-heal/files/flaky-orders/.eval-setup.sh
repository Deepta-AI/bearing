#!/usr/bin/env bash
# Builds this fixture's history in place on main: the baseline, the August
# sleep bump for TC-0203, the September discount refactor, and the
# export of the last 100 CI runs. Run from the
# fixture copy; it removes itself and .eval-prev first.
set -euo pipefail
rm -f .eval-setup.sh .eval-branch
export GIT_AUTHOR_NAME="Dev One" GIT_AUTHOR_EMAIL="dev.one@example.com"
export GIT_COMMITTER_NAME="Dev One" GIT_COMMITTER_EMAIL="dev.one@example.com"
at() { export GIT_AUTHOR_DATE="$1 +0530" GIT_COMMITTER_DATE="$1 +0530"; }

final=$(mktemp -d)
cp internal/pricing/discounts.go internal/notify/notifier_test.go docs/testing/healing-log.md docs/testing/ci-runs.csv "$final/"
cp .eval-prev/internal/pricing/discounts.go internal/pricing/discounts.go
rm -r .eval-prev
sed -i 's/time.Sleep(10 \* time.Millisecond)/time.Sleep(5 * time.Millisecond)/' internal/notify/notifier_test.go
rm docs/testing/healing-log.md docs/testing/ci-runs.csv

git init -q -b main
git add -A
at "2026-08-02T10:00:00"; git commit -q -m "orders: customers, discounts and receipt notifications"

cp "$final/notifier_test.go" internal/notify/notifier_test.go
cp "$final/healing-log.md" docs/testing/healing-log.md
git add -A
at "2026-08-14T16:20:00"; git commit -q -m "test(notify): give the receipt sender more time (TC-0203)"

cp "$final/discounts.go" internal/pricing/discounts.go
git add -A
at "2026-09-18T12:05:00"; git commit -q -m "pricing: key discount rules by code for the admin lookup (#212)"

cp "$final/ci-runs.csv" docs/testing/ci-runs.csv
git add -A
at "2026-09-26T18:40:00"; git commit -q -m "docs: export the last 100 CI runs of make check"
rm -r "$final"
