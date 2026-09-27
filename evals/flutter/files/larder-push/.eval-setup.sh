#!/usr/bin/env bash
# Builds this fixture's history in place. The files on disk are the tip of
# feature/push-notifications; .eval-base holds main's copy of every file
# the branch changes. main is the app as released (2.3.0); the branch adds
# two commits and is left checked out. Run from the fixture copy; it
# removes itself first.
set -euo pipefail
rm -f .eval-setup.sh .eval-branch
export GIT_AUTHOR_NAME="Dev Three" GIT_AUTHOR_EMAIL="dev.three@example.com"
export GIT_COMMITTER_NAME="Dev Three" GIT_COMMITTER_EMAIL="dev.three@example.com"
at() { export GIT_AUTHOR_DATE="$1 +0530" GIT_COMMITTER_DATE="$1 +0530"; }
tip=$(mktemp -d)
cp -a . "$tip/"
rm -rf "$tip/.eval-base"

# main: the released app.
cp -a .eval-base/. .
rm -rf .eval-base lib/features/push test/features/push
git init -q -b main
git add -A
at "2026-08-28T12:00:00"; git commit -q -m "feat: Larder 2.3.0 (profile, cart)"
git tag v2.3.0

# Branch commit 1: register for pushes and open tapped notifications.
git checkout -q -b feature/push-notifications
for p in pubspec.yaml config/prod.json lib/core/config.dart lib/main.dart \
  lib/app.dart lib/features/push/push_service.dart \
  lib/features/push/push_provider.dart; do
  mkdir -p "$(dirname "$p")"
  cp "$tip/$p" "$p"
done
git add -A
at "2026-09-23T15:20:00"; git commit -q -m "feat(push): register for order update notifications"

# Branch commit 2: the settings screen, its profile link and its test.
cp -a "$tip/lib/." lib/
cp -a "$tip/test/." test/
git add -A
at "2026-09-24T11:05:00"; git commit -q -m "feat(push): notification settings screen"
rm -rf "$tip"
