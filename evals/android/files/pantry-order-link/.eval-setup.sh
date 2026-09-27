#!/usr/bin/env bash
# Builds this fixture's history in place. The files on disk are the tip of
# feature/order-deeplink; .eval-base holds main's copy of every file the
# branch changes. main is the app as released (1.6.0); the branch adds two
# commits on top and is left checked out. Run from the fixture copy; it
# removes itself first.
set -euo pipefail
rm -f .eval-setup.sh .eval-branch
export GIT_AUTHOR_NAME="Dev Two" GIT_AUTHOR_EMAIL="dev.two@example.com"
export GIT_COMMITTER_NAME="Dev Two" GIT_COMMITTER_EMAIL="dev.two@example.com"
at() { export GIT_AUTHOR_DATE="$1 +0530" GIT_COMMITTER_DATE="$1 +0530"; }
tip=$(mktemp -d)
cp -a . "$tip/"
rm -rf "$tip/.eval-base"

# main: the released app.
cp -a .eval-base/. .
rm -rf .eval-base \
  app/src/main/java/com/example/pantry/ui/orderlink \
  app/src/test/java/com/example/pantry/ui/orderlink
git init -q -b main
git add -A
at "2026-06-12T11:00:00"; git commit -q -m "feat: Pantry 1.6.0 (sign in, orders)"
git tag v1.6.0

# Branch commit 1: the order link screen.
git checkout -q -b feature/order-deeplink
cp -a "$tip/app/." app/
cp "$tip/README.md" README.md
git add -A
at "2026-09-22T16:40:00"; git commit -q -m "feat(orders): open an order from an email link"

# Branch commit 2: the release crash fix.
cp "$tip/proguard-rules.pro" proguard-rules.pro
git add -A
at "2026-09-24T10:15:00"; git commit -q -m "fix(release): keep network models so the order link screen does not crash"
rm -rf "$tip"
