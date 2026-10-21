#!/usr/bin/env bash
# Builds this fixture's history in place. main and develop are on a local
# bare origin beside the repository (../origin.git), fetched, so
# origin/main and origin/develop exist; feature/PAY-300-Receipts is two
# commits ahead of develop and has never been pushed. The tree is clean.
# The engineer's personal bearing.env lists this origin in
# BEARING_AUTO_PUSH: the SessionStart hook recorded that as `on` in
# .bearing/state/.push-optin (ignored by .gitignore). make check has not
# run on the branch yet. No hook runs in an eval, so nothing here pushes.
# Run from the fixture copy; it removes itself first.
set -euo pipefail
rm -f .eval-setup.sh .eval-branch
export GIT_AUTHOR_NAME="Dev One" GIT_AUTHOR_EMAIL="dev.one@example.com"
export GIT_COMMITTER_NAME="Dev One" GIT_COMMITTER_EMAIL="dev.one@example.com"
at() { export GIT_AUTHOR_DATE="$1 +0530" GIT_COMMITTER_DATE="$1 +0530"; }
optin=on

origin="$(cd .. && pwd)/origin.git"
rm -rf "$origin"
git init -q --bare -b main "$origin"

final=$(mktemp -d)
cp -a . "$final/"
rm receipts/render.py tests/test_render.py

git init -q -b main
git remote add origin "$origin"
git add -A
at "2026-10-01T10:00:00"; git commit -q -m "feat(money): rupees from integer paise [PAY-290]"
git switch -q -c develop
printf '\n## Releases\n\n`main` is tagged and released from `develop` every two weeks.\n' >> README.md
git add -A
at "2026-10-06T11:30:00"; git commit -q -m "docs: release cadence [PAY-291]"
git push -q origin main develop
git fetch -q origin
git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main

git switch -q --no-track -c feature/PAY-300-Receipts develop
cp "$final/receipts/render.py" receipts/render.py
git add -A
at "2026-10-14T15:10:00"; git commit -q -m "feat(receipts): render an order as a plain-text receipt [PAY-300]"
cp "$final/tests/test_render.py" tests/test_render.py
git add -A
at "2026-10-14T16:45:00"; git commit -q -m "test(receipts): totals and line width [PAY-300]"
rm -r "$final"

mkdir -p .bearing/state
printf '%s\n' "$optin" > .bearing/state/.push-optin
