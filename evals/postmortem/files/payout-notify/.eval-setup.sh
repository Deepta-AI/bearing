#!/usr/bin/env bash
# Builds this fixture's git history in place: the service with one retry and
# a 10 s provider timeout, the July postmortem (release v1.7.2), the release
# v1.8.0 on the morning of the incident that tightened the timeout and raised
# the retries, then the on-call notes and provider export the day after.
# The files on disk are the final tree; earlier versions are written here.
# Run from the fixture copy; it removes itself first.
set -euo pipefail
rm -f .eval-setup.sh .eval-branch
who() { export GIT_AUTHOR_NAME="$1" GIT_AUTHOR_EMAIL="$2" GIT_COMMITTER_NAME="$1" GIT_COMMITTER_EMAIL="$2"; }
at() { export GIT_AUTHOR_DATE="$1 +0530" GIT_COMMITTER_DATE="$1 +0530"; }
final=$(mktemp -d)
cp -a . "$final/"
restore() { for p in "$@"; do mkdir -p "$(dirname "$p")"; cp "$final/$p" "$p"; done; }

rm -r ops docs/postmortems
sed -i -e 's/"NOTIFY_MAX_RETRIES", "3"/"NOTIFY_MAX_RETRIES", "1"/' \
       -e 's/"PROVIDER_TIMEOUT_S", "2.0"/"PROVIDER_TIMEOUT_S", "10.0"/' notify/config.py
sed -i -e 's/^PROVIDER_TIMEOUT_S=2.0$/PROVIDER_TIMEOUT_S=10.0/' deploy/notify.env

git init -q -b main
git remote add origin git@gitlab.example.com:payouts/payout-notify.git
who "Dev Two" "dev.two@example.com"
git add -A
at "2026-06-15T10:00:00"; git commit -q -m "feat: payout sent emails after the nightly batch"

restore docs/postmortems/2026-07-03-statement-pdf-timeouts.md
git add -A
at "2026-07-06T15:20:00"; git commit -q -m "docs: postmortem for missing statement PDFs [PAY-198]"
git tag v1.7.2

who "Dev Three" "dev.three@example.com"
restore notify/config.py deploy/notify.env
git add -A
at "2026-09-24T11:00:00"; git commit -q -m "chore(notify): tighten provider timeout to 2s, allow 3 retries [PAY-231]"
git tag v1.8.0

who "Dev Two" "dev.two@example.com"
restore ops/2026-09-24-payout-notes.md ops/provider-accepted-2026-09-24.csv
git add -A
at "2026-09-25T10:15:00"; git commit -q -m "ops: on-call notes and provider export for the duplicate payout emails"
git update-ref refs/remotes/origin/main main
rm -r "$final"
