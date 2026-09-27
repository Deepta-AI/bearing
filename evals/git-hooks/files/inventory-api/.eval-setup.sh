#!/usr/bin/env bash
# Builds this fixture's history in place: main with three commits, the last two
# without the ticket id CONTRIBUTING.md asks for. The clone still carries the
# core.hooksPath=.husky left by the Husky era (ADR-0001), though .husky/ is
# gone, so git runs no hooks at all today. Run from the fixture copy; it
# removes itself first.
set -euo pipefail
rm -f .eval-setup.sh .eval-branch
export GIT_AUTHOR_NAME="Dev One" GIT_AUTHOR_EMAIL="dev.one@example.com"
export GIT_COMMITTER_NAME="Dev One" GIT_COMMITTER_EMAIL="dev.one@example.com"
at() { export GIT_AUTHOR_DATE="$1 +0530" GIT_COMMITTER_DATE="$1 +0530"; }

keep="$(mktemp -d)"
cp -R docs testdata "$keep/"
rm -rf docs/adr/0003-local-git-hooks.md testdata/receipts-sample.json

git init -q -b main
git add -A -- . ':!internal/stock/stock_test.go' ':!testdata'
at "2026-03-02T10:00:00"; git commit -q -m "feat(stock): store, reservations and API [INV-12]"

cp "$keep/docs/adr/0003-local-git-hooks.md" docs/adr/
git add -A -- docs
at "2026-03-18T15:20:00"; git commit -q -m "docs: adr for local hooks"

cp -R "$keep/testdata/." testdata/
git add -A
at "2026-04-09T11:05:00"; git commit -q -m "added receipt tests"
rm -rf "$keep"

git config core.hooksPath .husky
