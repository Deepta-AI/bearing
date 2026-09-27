#!/usr/bin/env bash
# Builds this fixture's history: main holds capture, feature/refunds adds
# refunds on top (its last commit a behaviour-changing "refactor"), main then
# gains the webhook test after the branch was cut, and feature/refunds is
# checked out. Removes itself first.
set -euo pipefail
rm -f .eval-setup.sh .eval-branch
export GIT_AUTHOR_NAME="Dev One" GIT_AUTHOR_EMAIL="dev.one@example.com"
export GIT_COMMITTER_NAME="Dev One" GIT_COMMITTER_EMAIL="dev.one@example.com"
at() { export GIT_AUTHOR_DATE="$1 +0530" GIT_COMMITTER_DATE="$1 +0530"; }

git init -q -b main
git add go.mod Makefile README.md CLAUDE.md
at "2026-08-20T10:00:00"; git commit -q -m "chore: scaffold paygate"

git add internal/payment/capture.go internal/payment/capture_test.go migrations/0001_payments.sql docs/adr
# main's backlog has EP-02 and the planned EP-04; the refunds epic EP-03
# arrives on the branch.
full=$(cat docs/product/backlog.md)
awk '/^## EP-03/{drop=1; next} /^## EP-/{drop=0} !drop' docs/product/backlog.md > backlog.tmp
mv backlog.tmp docs/product/backlog.md
git add docs/product/backlog.md
at "2026-08-24T12:00:00"; git commit -q -m "feat(payment): capture and over-capture guard (US-02-001, US-02-002)"
git add internal/payment/webhook.go
mv internal/payment/webhook_test.go webhook_test.tmp
at "2026-08-27T15:00:00"; git commit -q -m "feat(payment): map gateway webhook statuses (US-02-003)"

git checkout -q -b feature/refunds
printf '%s\n' "$full" > docs/product/backlog.md
git add docs/product/backlog.md
at "2026-09-14T10:00:00"; git commit -q -m "docs(backlog): refunds epic EP-03"
# refund.go and partial.go first land without the shared validAmount helper;
# a later "refactor" labelled US-03-001 moves Partial onto it and drops the
# already-refunded amount from the check.
final_refund=$(cat internal/refund/refund.go)
final_partial=$(cat internal/refund/partial.go)
awk '/^\/\/ validAmount/{exit} {print}' internal/refund/refund.go > refund.tmp
printf '%s\n' "$(cat refund.tmp)" > internal/refund/refund.go
rm -f refund.tmp
git add internal/refund/refund.go migrations/0002_refunds.sql
at "2026-09-16T11:00:00"; git commit -q -m "feat(refund): full refunds with idempotency keys (US-03-001, US-03-002)"
git add internal/refund/refund_test.go
at "2026-09-17T17:00:00"; git commit -q -m "test(refund): full refund and repeated key"
sed 's/if !validAmount(p, amount) {/if amount <= 0 || amount > p.Captured-p.Refunded {/' internal/refund/partial.go > partial.tmp
mv partial.tmp internal/refund/partial.go
git add internal/refund/partial.go internal/refund/partial_test.go
at "2026-09-22T12:30:00"; git commit -q -m "feat(refund): partial refunds (US-03-003)"
printf '%s\n' "$final_refund" > internal/refund/refund.go
printf '%s\n' "$final_partial" > internal/refund/partial.go
git add internal/refund/refund.go internal/refund/partial.go
at "2026-09-24T16:10:00"; git commit -q -m "refactor(refund): one place for amount checks (US-03-001)"

# main moves on after the branch was cut: the webhook finally gets its test.
git checkout -q main
mv webhook_test.tmp internal/payment/webhook_test.go
git add internal/payment/webhook_test.go
at "2026-09-23T09:15:00"; git commit -q -m "test(payment): webhook status mapping (US-02-003)"
git checkout -q feature/refunds
test -z "$(git status --porcelain)"
