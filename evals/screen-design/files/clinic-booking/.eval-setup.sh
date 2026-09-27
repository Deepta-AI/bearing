#!/usr/bin/env bash
# Builds this fixture's history in place. The files on disk are the tip of
# main. Commit 1 is the app with the round 1 mockups exactly as build.py
# generates them; commit 2 is a hand edit to S-03-confirm.html (the legal
# cancellation wording, never copied into screens.json); commit 3 adds the
# client's round 1 notes. Run from the fixture copy; it removes itself first.
set -euo pipefail
rm -f .eval-setup.sh .eval-branch
export GIT_AUTHOR_NAME="Dev One" GIT_AUTHOR_EMAIL="dev.one@example.com"
export GIT_COMMITTER_NAME="Dev One" GIT_COMMITTER_EMAIL="dev.one@example.com"
at() { export GIT_AUTHOR_DATE="$1 +0530" GIT_COMMITTER_DATE="$1 +0530"; }
tip=$(mktemp -d)
cp docs/design/screens/booking/S-03-confirm.html "$tip/"
cp docs/design/feedback/round1.md "$tip/"

# Commit 1: app skeleton and round 1 mockups, straight from build.py.
rm docs/design/feedback/round1.md
python3 docs/design/screens/booking/build.py >/dev/null
git init -q -b main
git add -A
at "2026-09-22T15:10:00"; git commit -q -m "feat(booking): app skeleton and round 1 mockups"

# Commit 2: the cancellation wording from the legal review, edited by hand.
export GIT_AUTHOR_NAME="Ops Reviewer" GIT_AUTHOR_EMAIL="ops.reviewer@example.com"
cp "$tip/S-03-confirm.html" docs/design/screens/booking/S-03-confirm.html
git add -A
at "2026-09-24T11:40:00"; git commit -q -m "S-03: cancellation wording from legal review"

# Commit 3: the client's notes.
export GIT_AUTHOR_NAME="Dev One" GIT_AUTHOR_EMAIL="dev.one@example.com"
cp "$tip/round1.md" docs/design/feedback/round1.md
git add -A
at "2026-09-25T18:05:00"; git commit -q -m "docs: client notes on the booking mockups, round 1"
rm -r "$tip"
