#!/usr/bin/env bash
# Builds this fixture's history: the scaffold committed in February 2025,
# the first store release in September 2025 and the 1.4.0 release in May
# 2026, with the origin remote on the company's own GitLab. The files on
# disk are the final working tree.
set -euo pipefail
rm -f .eval-setup.sh .eval-branch
export GIT_AUTHOR_NAME="Dev One" GIT_AUTHOR_EMAIL="dev.one@larkspur.dev"
export GIT_COMMITTER_NAME="Dev One" GIT_COMMITTER_EMAIL="dev.one@larkspur.dev"
at() { export GIT_AUTHOR_DATE="$1 +0530" GIT_COMMITTER_DATE="$1 +0530"; }
git init -q -b main
at "2025-02-11 10:30:00"
git add package.json Makefile src test .gitignore
git commit -q -m "Scaffold the Fieldnotes API from the template"
at "2025-09-12 17:05:00"
git add mobile .gitlab SECURITY.md README.md
git commit -q -m "Add the Expo app and the repository policy files"
at "2026-05-19 12:00:00"
git add -A
git commit -q -m "Release 1.4.0"
git remote add origin git@git.larkspur.dev:larkspur/fieldnotes.git
