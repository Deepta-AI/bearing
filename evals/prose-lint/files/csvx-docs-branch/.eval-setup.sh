#!/usr/bin/env bash
# Builds this fixture's history in place. The files on disk are the tip of
# feat/rating-filter; .eval-base holds main's copy of every file the branch
# changes. The kit forbids the em dash character in its own tree, so the
# fixture spells it {{EMDASH}} and this script puts the real character back
# before anything is committed. Run from the fixture copy; it removes itself.
set -euo pipefail
rm -f .eval-setup.sh .eval-branch
dash=$(printf '\xe2\x80\x94')
grep -rl --exclude-dir=.git '{{EMDASH}}' . | while read -r f; do
  sed -i "s/{{EMDASH}}/$dash/g" "$f"
done
export GIT_AUTHOR_NAME="Dev One" GIT_AUTHOR_EMAIL="dev.one@example.com"
export GIT_COMMITTER_NAME="Dev One" GIT_COMMITTER_EMAIL="dev.one@example.com"
at() { export GIT_AUTHOR_DATE="$1 +0530" GIT_COMMITTER_DATE="$1 +0530"; }
tip=$(mktemp -d)
cp -a . "$tip/"
rm -rf "$tip/.eval-base"

# main: csvx as released, copy and column selection only.
cp -a .eval-base/. .
rm -rf .eval-base tests/test_cli.py docs/export.md
git init -q -b main
git add -A
at "2026-08-03T10:00:00"; git commit -q -m "feat: csvx copies a review export, optionally keeping some columns"

# Branch commit 1: the rating filter and batched writes.
git checkout -q -b feat/rating-filter
cp "$tip/csvx/cli.py" "$tip/csvx/export.py" csvx/
cp "$tip/tests/test_export.py" "$tip/tests/test_cli.py" tests/
git add -A
at "2026-09-23T15:20:00"; git commit -q -m "feat: --min-rating filter and batched writes"

# Branch commit 2: the docs.
cp "$tip/README.md" README.md
mkdir -p docs && cp "$tip/docs/export.md" docs/export.md
git add -A
at "2026-09-24T11:05:00"; git commit -q -m "docs: document --min-rating and how an export runs"
rm -rf "$tip"
