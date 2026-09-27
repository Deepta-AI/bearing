#!/usr/bin/env bash
# Builds this fixture's history in place. The files on disk are the tip of
# feature/refund-webhook; .eval-base holds main's copy of every file the
# branch changes. main is the API as released (0.9.0); the branch adds one
# commit and is left checked out. Run from the fixture copy; it removes
# itself first.
set -euo pipefail
rm -f .eval-setup.sh .eval-branch
export GIT_AUTHOR_NAME="Dev Two" GIT_AUTHOR_EMAIL="dev.two@example.com"
export GIT_COMMITTER_NAME="Dev Two" GIT_COMMITTER_EMAIL="dev.two@example.com"
at() { export GIT_AUTHOR_DATE="$1 +0530" GIT_COMMITTER_DATE="$1 +0530"; }
tip=$(mktemp -d)
cp -a . "$tip/"
rm -rf "$tip/.eval-base"

# main: the released API.
cp -a .eval-base/. .
rm -rf .eval-base app/webhooks/refunds.py tests/test_refunds.py
git init -q -b main
git add -A
at "2026-09-10T11:00:00"; git commit -q -m "feat: invoices-api 0.9.0 (customers, invoices, payment webhooks)"
git tag v0.9.0

# The branch: refund events.
git checkout -q -b feature/refund-webhook
cp -a "$tip/." .
git add -A
at "2026-09-25T17:20:00"; git commit -q -m "feat(webhooks): record provider refunds on the invoice (INV-57)"
rm -rf "$tip"
