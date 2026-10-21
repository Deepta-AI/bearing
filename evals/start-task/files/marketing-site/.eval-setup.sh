#!/usr/bin/env bash
# Builds this fixture's history in place: a marketing site on trunk (main
# only, no develop) with origin/main as a remote-tracking ref for an origin
# that is not reachable, main checked out and clean. No .bearing/ yet: no
# flow has been recorded for this repository.
# Run from the fixture copy; it removes itself first.
set -euo pipefail
rm -f .eval-setup.sh .eval-branch
export GIT_AUTHOR_NAME="Dev One" GIT_AUTHOR_EMAIL="dev.one@example.com"
export GIT_COMMITTER_NAME="Dev One" GIT_COMMITTER_EMAIL="dev.one@example.com"
at() { export GIT_AUTHOR_DATE="$1 +0530" GIT_COMMITTER_DATE="$1 +0530"; }

final=$(mktemp -d)
cp -a . "$final/"
rm -r src/app/about

git init -q -b main
git remote add origin git@gitlab.example.com:shop/shop-site.git
git add -A
at "2026-10-02T09:40:00"; git commit -q -m "feat(home): home page [WEB-1]"
cp -R "$final/src/app/about" src/app/about
git add -A
at "2026-10-09T14:05:00"; git commit -q -m "feat(about): about page [WEB-3]"
git update-ref refs/remotes/origin/main main
git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
rm -r "$final"
