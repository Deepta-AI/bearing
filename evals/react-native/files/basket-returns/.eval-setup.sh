#!/usr/bin/env bash
# Builds this fixture's history in place. The files on disk are the tip of
# feature/BSK-41-return-photos; .eval-base holds main's copy of every file
# the branch changes. main is the app as released (2.3.0); the branch adds
# two commits and is left checked out. Run from the fixture copy; it
# removes itself first.
set -euo pipefail
rm -f .eval-setup.sh .eval-branch
export GIT_AUTHOR_NAME="Dev One" GIT_AUTHOR_EMAIL="dev.one@example.com"
export GIT_COMMITTER_NAME="Dev One" GIT_COMMITTER_EMAIL="dev.one@example.com"
at() { export GIT_AUTHOR_DATE="$1 +0530" GIT_COMMITTER_DATE="$1 +0530"; }
tip=$(mktemp -d)
cp -a . "$tip/"
rm -rf "$tip/.eval-base"

# main: the released app.
cp -a .eval-base/. .
rm -rf .eval-base src/features/returns "app/(app)/returns"
git init -q -b main
git add -A
at "2026-09-10T11:00:00"; git commit -q -m "feat: Basket 2.3.0 (sign in, addresses, order detail)"
git tag v2.3.0

# Branch commit 1: the return request screen.
git checkout -q -b feature/BSK-41-return-photos
cp -a "$tip/src/features/returns" src/features/
mkdir -p "app/(app)/returns"
cp "$tip/app/(app)/returns/new.tsx" "app/(app)/returns/new.tsx"
cp "$tip/app/(app)/orders/[id].tsx" "app/(app)/orders/[id].tsx"
cp "$tip/package.json" package.json
git add -A
at "2026-09-23T15:20:00"; git commit -q -m "feat(returns): request a return with photos (BSK-41)"

# Branch commit 2: upload configuration and the camera prompt.
cp "$tip/app/_layout.tsx" app/_layout.tsx
cp "$tip/eas.json" eas.json
cp "$tip/.env.example" .env.example
git add -A
at "2026-09-25T18:05:00"; git commit -q -m "feat(returns): bucket config per profile, ask for the camera at start (BSK-41)"
rm -rf "$tip"
