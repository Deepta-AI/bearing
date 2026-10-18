#!/usr/bin/env bash
# Builds this fixture's git history in place: main and develop at the
# first commit, branch feat/TASK-7-theme one commit ahead whose only
# change is src/styles/theme.css, and a .bearing/state/.check-changed-passed
# marker written after that commit, so it is newer than the change.
# Run from the fixture copy; it removes itself first.
set -euo pipefail
rm -f .eval-setup.sh
export GIT_AUTHOR_NAME="Dev One" GIT_AUTHOR_EMAIL="dev.one@example.com"
export GIT_COMMITTER_NAME="Dev One" GIT_COMMITTER_EMAIL="dev.one@example.com"
at() { export GIT_AUTHOR_DATE="$1 +0530" GIT_COMMITTER_DATE="$1 +0530"; }
final=$(mktemp -d)
cp src/styles/theme.css "$final/theme.css"
cat > src/styles/theme.css <<'CSS'
:root {
  --color-brand: #0b5fff;
  --space-card: 16px;
}
CSS
git init -q -b main
at "2026-10-01 10:00:00"
git add -A
git commit -q -m "storefront: format, checkout and home"
git branch develop
git checkout -q -b feat/TASK-7-theme
at "2026-10-05 12:00:00"
cp "$final/theme.css" src/styles/theme.css
git commit -q -am "theme: wider card spacing (TASK-7)"
sleep 1
mkdir -p .bearing/state
touch .bearing/state/.check-changed-passed
rm -r "$final"
