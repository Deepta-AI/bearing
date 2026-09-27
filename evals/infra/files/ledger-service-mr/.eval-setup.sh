#!/usr/bin/env bash
# Builds this fixture's history in place. The files on disk are main; .mr/
# holds the branch's copy of every file the merge request's first commit adds
# or changes, .mr2/ the files its second commit changes. main is committed
# first, then feat/ledger-worker gets two commits and is left checked out.
# plans/ (the CI plan text the reviewer was handed) was produced from the
# FIRST branch commit, stays untracked, and gets that commit's short id.
# Run from the fixture copy; it removes itself first.
set -euo pipefail
rm -f .eval-setup.sh .eval-branch
export GIT_AUTHOR_NAME="Dev One" GIT_AUTHOR_EMAIL="dev.one@example.com"
export GIT_COMMITTER_NAME="Dev One" GIT_COMMITTER_EMAIL="dev.one@example.com"
at() { export GIT_AUTHOR_DATE="$1 +0530" GIT_COMMITTER_DATE="$1 +0530"; }
mr=$(mktemp -d); mr2=$(mktemp -d); plans=$(mktemp -d)
cp -a .mr/. "$mr/"; cp -a .mr2/. "$mr2/"; cp -a plans/. "$plans/"
rm -rf .mr .mr2 plans

git init -q -b main
git add -A
at "2026-09-01T10:00:00"; git commit -q -m "feat: ledger api, database and secrets in dev, qa and prod"

git checkout -q -b feat/ledger-worker
cp -a "$mr/." .
git add -A
at "2026-09-25T17:20:00"; git commit -q -F - <<'MSG'
feat: add ledger-worker and tidy database naming

- New ledger-worker deployment that posts pending ledger entries every 5 s.
- ledger-worker service account with Cloud SQL client and Secret Manager
  access so it can read the database password.
- Database instances renamed to ledger-<env>-db to match the naming
  convention of everything else.
- LedgerWorkerLag alert.

Rollout: dev, then qa, then prod. In prod this is the new worker plus a
naming tidy; no data changes.
MSG
plan_commit=$(git rev-parse --short HEAD)

cp -a "$mr2/." .
git add -A
at "2026-09-26T11:05:00"; git commit -q -F - <<'MSG'
refactor(iam): make service-account project roles authoritative

A role taken out of project_roles is now revoked for real instead of
lingering after state drift.
MSG
mkdir -p plans; cp -a "$plans/." plans/
sed -i "s/@PLAN_COMMIT@/$plan_commit/" plans/*.txt
rm -rf "$mr" "$mr2" "$plans"
