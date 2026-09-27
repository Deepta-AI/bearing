#!/usr/bin/env bash
# Builds this fixture's history in place. The files on disk are the final
# tree of feat/customer-notes; .eval-main/ holds main's versions of the files
# that branch changes. main gets two commits, the branch one, and the branch
# is left checked out. Run from the fixture copy.
set -euo pipefail
rm -f .eval-setup.sh .eval-branch
export GIT_AUTHOR_NAME="Dev One" GIT_AUTHOR_EMAIL="dev.one@example.com"
export GIT_COMMITTER_NAME="Dev One" GIT_COMMITTER_EMAIL="dev.one@example.com"
at() { export GIT_AUTHOR_DATE="$1 +0530" GIT_COMMITTER_DATE="$1 +0530"; }
final=$(mktemp -d)
cp -a . "$final/"
rm -rf "$final/.eval-main"

# main: the customers screens.
cp -a .eval-main/. .
rm -rf .eval-main src/features/notes
git init -q -b main
git add -A -- . ':!docs/adr/0002-no-customer-data-in-browser-storage.md' ':!src/app/ui-store.ts'
at "2026-03-10T11:00:00"
git commit -q -m "feat(customers): search and customer detail"
git add -A
at "2026-05-20T15:40:00"
git commit -q -m "docs: ADR-0002 no customer data in browser storage; persist UI density only"

git checkout -q -b feat/customer-notes
cp -a "$final/." .
git add -A
at "2026-09-24T18:05:00"
git commit -q -m "feat(notes): notes panel on the customer page

Agents asked to keep notes on a customer. Adds the notes list, add and
delete, and a Summarise button that summarises the notes.

Pilot: this commit was built with the team's .env and deployed to
pilot.support-console.internal this evening for the six agents on the
morning shift, so they can try it before the merge."
rm -rf "$final"
