#!/usr/bin/env bash
# Builds this fixture's git history in place: main holds the service as it
# ships today (JSON reports, the weekly digest, the nightly CSV archive for
# the warehouse); the feature branch adds the customer CSV export on top.
# Files under .eval-base/ are main's versions of the files the branch
# changes. Run from the fixture copy; it removes itself first.
set -euo pipefail
rm -f .eval-setup.sh .eval-branch
export GIT_AUTHOR_NAME="Dev One" GIT_AUTHOR_EMAIL="dev.one@example.com"
export GIT_COMMITTER_NAME="Dev One" GIT_COMMITTER_EMAIL="dev.one@example.com"
at() { export GIT_AUTHOR_DATE="$1 +0000" GIT_COMMITTER_DATE="$1 +0000"; }

branch_copy="$(mktemp -d)"
cp -R . "$branch_copy/tree"
rm -r "$branch_copy/tree/.eval-base"
cp -R .eval-base/. .
rm -r .eval-base

git init -q -b main
git remote add origin git@code.example.internal:analytics/reportsvc.git
git add -A
at "2026-09-01T10:00:00"
git commit -q -m "reportsvc: reports API, weekly digest, nightly archive"
git update-ref refs/remotes/origin/main main
git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main

git checkout -q -b feature/REP-231-csv-export
cp -R "$branch_copy/tree/." .
rm -r "$branch_copy"
git add -A
at "2026-09-24T15:00:00"
git commit -q -m "feat(reports): CSV export endpoint, digest attachments and links [REP-231]"
