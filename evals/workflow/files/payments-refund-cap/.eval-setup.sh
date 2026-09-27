#!/usr/bin/env bash
# Builds this fixture's history in place. main was cut on 8 Sep; origin/main
# gained a payouts migration on 17 Sep that this branch has not picked up;
# origin/feature/PAY-221-chargebacks (in review since 24 Sep) already holds
# migration 0004;
# feature/PAY-214-refund-cap has two commits and uncommitted work from 19 Sep.
# Run from the fixture copy; it removes itself and its stages.
set -euo pipefail
rm -f .eval-setup.sh .eval-branch
S=.eval-stages
who() { export GIT_AUTHOR_NAME="$1" GIT_AUTHOR_EMAIL="$2" GIT_COMMITTER_NAME="$1" GIT_COMMITTER_EMAIL="$2"; }
at() { export GIT_AUTHOR_DATE="$1 +0530" GIT_COMMITTER_DATE="$1 +0530"; }

git init -q -b main
echo "$S/" >> .git/info/exclude
git remote add origin git@code.example.internal:payments/payments.git
who "Dev One" dev.one@example.com
git add -A
at "2026-09-08T10:00:00"; git commit -q -m "feat(refunds): refunds endpoint with in-memory store [PAY-200]"
git update-ref refs/remotes/origin/main main

# origin/main moves on (merged by a teammate; this clone's main was not pulled).
git checkout -q -b tmp-payouts
cp -R "$S/payouts/." .
who "Dev Two" dev.two@example.com
git add -A
at "2026-09-17T15:20:00"; git commit -q -m "feat(payouts): payouts table [PAY-209]"
git update-ref refs/remotes/origin/main tmp-payouts

# A teammate's branch, cut from the new origin/main and in review, already
# holds migration 0004. Only its remote-tracking ref exists in this clone.
git checkout -q -b tmp-chargebacks
cp -R "$S/chargebacks/." .
who "Dev Three" dev.three@example.com
git add -A
at "2026-09-24T12:45:00"; git commit -q -m "feat(chargebacks): chargebacks table [PAY-221]"
git update-ref refs/remotes/origin/feature/PAY-221-chargebacks tmp-chargebacks
git checkout -q main
git branch -q -D tmp-chargebacks
git branch -q -D tmp-payouts
git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main

# The task branch.
who "Dev One" dev.one@example.com
git checkout -q -b feature/PAY-214-refund-cap
cp -R "$S/start/." .
git add -A
at "2026-09-15T09:30:00"; git commit -q -m "chore(PAY-214): start task, progress record"
cp -R "$S/cap/." .
git add -A
at "2026-09-18T17:05:00"; git commit -q -m "feat(refunds): reject refunds above the remaining captured amount [PAY-214]"
git update-ref refs/remotes/origin/feature/PAY-214-refund-cap HEAD
git branch -q --set-upstream-to=origin/feature/PAY-214-refund-cap

# Uncommitted work from the last session, and the local session notes.
cp "$S/wip/internal/refunds/handler.go" internal/refunds/handler.go
cp "$S/wip/internal/refunds/audit.go" internal/refunds/audit.go
cp "$S/wip/migrations/0002_refunds.sql" migrations/0002_refunds.sql
mkdir -p .bearing/state
cp "$S/wip/dotbearing/state/feature_PAY-214-refund-cap.md" .bearing/state/
touch -d "2026-09-19 18:40" .bearing/state/feature_PAY-214-refund-cap.md internal/refunds/audit.go internal/refunds/handler.go migrations/0002_refunds.sql
rm -rf "$S"
sed -i '/^\.eval-stages\/$/d' .git/info/exclude
