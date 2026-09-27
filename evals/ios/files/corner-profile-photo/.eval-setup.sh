#!/usr/bin/env bash
# Builds this fixture's history in place. The files on disk are the tip of
# feature/profile-photo; .eval-base holds main's copy of every file the
# branch changes, and .eval-mid the files whose state after the branch's
# first commit differs from the tip. main is the released app (2.3.0); the
# branch adds two commits and is left checked out. Run from the fixture
# copy; it removes itself first.
set -euo pipefail
rm -f .eval-setup.sh .eval-branch
export GIT_AUTHOR_NAME="Dev Two" GIT_AUTHOR_EMAIL="dev.two@example.com"
export GIT_COMMITTER_NAME="Dev Two" GIT_COMMITTER_EMAIL="dev.two@example.com"
at() { export GIT_AUTHOR_DATE="$1 +0530" GIT_COMMITTER_DATE="$1 +0530"; }
tip=$(mktemp -d)
mid=$(mktemp -d)
cp -a . "$tip/"
cp -a .eval-mid/. "$mid/"
rm -rf "$tip/.eval-base" "$tip/.eval-mid"

# main: the released app.
cp -a .eval-base/. .
rm -rf .eval-base .eval-mid \
  App/ProfileView.swift App/CameraPicker.swift \
  Packages/CornerKit/Sources/Features/Profile \
  Packages/CornerKit/Tests/FeaturesTests/ProfilePhotoModelTests.swift
git init -q -b main
git add -A
at "2026-09-08T11:00:00"; git commit -q -m "feat: Corner 2.3.0 (orders)"
git tag v2.3.0

# Branch commit 1: the Profile tab with camera and library upload.
git checkout -q -b feature/profile-photo
cp -a "$tip/." .
cp -a "$mid/." .
git add -A
at "2026-09-23T15:20:00"; git commit -q -m "feat(profile): set a profile photo from the camera or the library"

# Branch commit 2: the upload was always 401.
cp "$tip/App/AppContainer.swift" App/AppContainer.swift
git add -A
at "2026-09-24T18:05:00"; git commit -q -m "fix(profile): give the photo upload the access token"
rm -rf "$tip" "$mid"
