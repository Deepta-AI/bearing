#!/usr/bin/env bash
# Builds this fixture's history on main: a scaffold, one commit per ticket,
# and the test-case and coverage docs last. Removes itself first.
set -euo pipefail
rm -f .eval-setup.sh .eval-branch
export GIT_AUTHOR_NAME="Dev One" GIT_AUTHOR_EMAIL="dev.one@example.com"
export GIT_COMMITTER_NAME="Dev One" GIT_COMMITTER_EMAIL="dev.one@example.com"
at() { export GIT_AUTHOR_DATE="$1 +0530" GIT_COMMITTER_DATE="$1 +0530"; }

git init -q -b main
git add go.mod Makefile README.md CLAUDE.md cmd docs/product/PRD.md docs/product/backlog.md docs/analytics
at "2026-09-01T10:00:00"; git commit -q -m "chore: scaffold shiftboard service"

git add internal/swap/swap.go internal/swap/request_test.go migrations/0001_swaps.sql docs/adr/0001-postgres-for-swaps.md
at "2026-09-03T11:00:00"; git commit -q -m "feat(swap): staff can request a colleague's shift [SHF-11]"

git add internal/swap/decision.go internal/swap/decision_test.go migrations/0002_swap_decisions.sql
at "2026-09-05T15:00:00"; git commit -q -m "feat(swap): manager approves or rejects a swap [SHF-12]"

# The rest rule lands with its midnight test running; the skip comes later.
final=$(cat internal/swap/rest_test.go)
grep -v 't.Skip(' internal/swap/rest_test.go > rest_test.tmp && mv rest_test.tmp internal/swap/rest_test.go
git add internal/swap/rest.go internal/swap/rest_test.go docs/adr/0002-rest-rule-in-service.md
at "2026-09-09T12:00:00"; git commit -q -m "feat(swap): block swaps that break the 11 hour rest rule [SHF-13]"
printf '%s\n' "$final" > internal/swap/rest_test.go
git add internal/swap/rest_test.go
at "2026-09-12T18:40:00"; git commit -q -m "test(swap): skip the midnight rest case to unblock CI"

git add internal/audit migrations/0003_swap_audit.sql
at "2026-09-15T16:00:00"; git commit -q -m "feat(audit): record every swap state change [SHF-21]"

git add docs/testing docs/product/coverage.md
at "2026-09-18T10:30:00"; git commit -q -m "docs: test cases and coverage for release 1.4"
test -z "$(git status --porcelain)"
