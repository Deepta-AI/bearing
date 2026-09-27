#!/usr/bin/env bash
# Builds this fixture's git history in place: main holds linkd as it ships
# today; the feature branch adds link expiry on top in one commit, written
# with an AI assistant. Files under .eval-base/ are main's versions of the
# files the branch changes; BRANCH_ONLY lists the files the branch adds.
# Run from the fixture copy; it removes itself first.
set -euo pipefail
rm -f .eval-setup.sh .eval-branch
export GIT_AUTHOR_NAME="Dev One" GIT_AUTHOR_EMAIL="dev.one@example.com"
export GIT_COMMITTER_NAME="Dev One" GIT_COMMITTER_EMAIL="dev.one@example.com"
at() { export GIT_AUTHOR_DATE="$1 +0530" GIT_COMMITTER_DATE="$1 +0530"; }
BRANCH_ONLY="internal/links/expiry.go internal/links/expiry_test.go internal/api/util.go scripts/archive-expired.sh ops/crontab"

branch_copy="$(mktemp -d)"
cp -R . "$branch_copy/tree"
rm -r "$branch_copy/tree/.eval-base"
cp -R .eval-base/. .
rm -r .eval-base
# shellcheck disable=SC2086
rm $BRANCH_ONLY
rmdir scripts ops

git init -q -b main
git remote add origin git@code.example.internal:marketing/linkd.git
git add -A
at "2026-08-20T10:00:00"
git commit -q -m "linkd: short links with a JSON file store"
git update-ref refs/remotes/origin/main main
git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main

git checkout -q -b feature/LNK-14-link-expiry
cp -R "$branch_copy/tree/." .
rm -r "$branch_copy"
git add -A
at "2026-09-25T16:30:00"
git commit -q -m "feat(links): expiring links, 410 once expired, nightly archive of expired links [LNK-14]"
