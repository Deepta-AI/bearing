#!/usr/bin/env bash
# Builds this fixture's git history in place: one branch, trunk (the
# repository's default branch), with origin on the team's self-hosted
# GitLab. Run from the fixture copy; it removes itself first.
set -euo pipefail
rm -f .eval-setup.sh .eval-branch
export GIT_AUTHOR_NAME="Dev One" GIT_AUTHOR_EMAIL="dev.one@example.com"
export GIT_COMMITTER_NAME="Dev One" GIT_COMMITTER_EMAIL="dev.one@example.com"
at() { export GIT_AUTHOR_DATE="$1 +0530" GIT_COMMITTER_DATE="$1 +0530"; }

git init -q -b trunk
git remote add origin git@code.example.internal:finance/ledger-api.git
git add -A
at "2026-09-10T11:00:00"; git commit -q -m "feat(ledger): postings, balances and the JSON API [FIN-12]"
git update-ref refs/remotes/origin/trunk trunk
git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/trunk
