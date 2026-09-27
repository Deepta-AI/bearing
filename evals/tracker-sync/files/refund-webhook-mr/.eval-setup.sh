#!/usr/bin/env bash
# Builds this fixture's history in place. The files on disk are the tip of
# feat/SHOP-142-refund-webhook; .eval-base holds main's copy of the one file
# the branch changes (src/logger.js). main is also origin/main. The branch has
# three commits, is pushed (origin has it) and is left checked out; it is not
# merged. Removes itself first.
set -euo pipefail
rm -f .eval-setup.sh .eval-branch
export GIT_AUTHOR_NAME="Dev Two" GIT_AUTHOR_EMAIL="dev.two@example.com"
export GIT_COMMITTER_NAME="Dev Two" GIT_COMMITTER_EMAIL="dev.two@example.com"
at() { export GIT_AUTHOR_DATE="$1 +0530" GIT_COMMITTER_DATE="$1 +0530"; }
tip=$(mktemp -d)
cp -a . "$tip/"
rm -rf "$tip/.eval-base"

# main: the service before this work.
cp -a .eval-base/. .
rm -rf .eval-base src/webhook.js test/webhook.test.js docs/adr/0007-verify-refund-webhook-signatures.md
git init -q -b main
git remote add origin git@git.example.test:shop/payments.git
git add -A
at "2026-09-15T11:00:00"; git commit -q -m "SHOP-118: refunds are final once succeeded"
git update-ref refs/remotes/origin/main HEAD

git checkout -q -b feat/SHOP-142-refund-webhook
cp "$tip/src/webhook.js" src/webhook.js
git add -A
at "2026-09-23T15:10:00"; git commit -q -m "SHOP-142: verify refund webhook signatures"

cp "$tip/src/logger.js" src/logger.js
git add -A
at "2026-09-24T09:40:00"; git commit -q -m "SHOP-150: default production log level to info"

cp "$tip/test/webhook.test.js" test/webhook.test.js
cp "$tip/docs/adr/0007-verify-refund-webhook-signatures.md" docs/adr/
git add -A
at "2026-09-25T18:20:00"; git commit -q -m "SHOP-142: tests for TC-031 to TC-033, ADR-0007"
git update-ref refs/remotes/origin/feat/SHOP-142-refund-webhook HEAD
git branch -q --set-upstream-to=origin/feat/SHOP-142-refund-webhook
rm -rf "$tip"
