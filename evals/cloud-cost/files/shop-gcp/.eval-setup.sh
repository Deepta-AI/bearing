#!/usr/bin/env bash
# Commits the tree on main as of 2 September 2026. Removes itself.
set -euo pipefail
rm -f .eval-setup.sh .eval-branch
export GIT_AUTHOR_NAME="Dev One" GIT_AUTHOR_EMAIL="dev.one@example.com"
export GIT_COMMITTER_NAME="Dev One" GIT_COMMITTER_EMAIL="dev.one@example.com"
export GIT_AUTHOR_DATE="2026-09-02T10:00:00 +0530" GIT_COMMITTER_DATE="2026-09-02T10:00:00 +0530"
git init -q -b main
git add -A
git commit -q -m "billing: August export"
