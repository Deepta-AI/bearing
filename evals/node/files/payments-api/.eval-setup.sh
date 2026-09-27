#!/usr/bin/env bash
# Builds this fixture's history in place. The files on disk are the tip of
# feat/refunds; .eval-base holds main's copy of every file the branch
# changes. main is the service as deployed; the branch adds one commit and is
# left checked out. Run from the fixture copy; it removes itself first.
set -euo pipefail
rm -f .eval-setup.sh .eval-branch
export GIT_AUTHOR_NAME="Dev One" GIT_AUTHOR_EMAIL="dev.one@example.com"
export GIT_COMMITTER_NAME="Dev One" GIT_COMMITTER_EMAIL="dev.one@example.com"
at() { export GIT_AUTHOR_DATE="$1 +0530" GIT_COMMITTER_DATE="$1 +0530"; }
tip=$(mktemp -d)
cp -a . "$tip/"
rm -rf "$tip/.eval-base"

# main: payments and idempotency keys.
cp -a .eval-base/. .
rm -rf .eval-base src/routes/refunds.ts src/routes/refunds.test.ts src/ledger.ts drizzle/0002_refunds.sql
git init -q -b main
git add -A
at "2026-05-20T12:00:00"; git commit -q -m "feat(payments): idempotent payment creation (ADR-0003)"

# feat/refunds: one commit.
git checkout -q -b feat/refunds
cp -a "$tip/." .
git add -A
at "2026-09-25T18:20:00"; git commit -q -m "feat(refunds): refund endpoint for the support console"
rm -rf "$tip"
