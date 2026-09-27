#!/usr/bin/env bash
# Builds this fixture's history in place. The files on disk are the final
# tree of feat/invoice-bulk-actions; .eval-main/ holds main's versions of
# the files that branch changes. main gets one commit, the branch two, and
# the branch is left checked out. Run from the fixture copy.
set -euo pipefail
rm -f .eval-setup.sh .eval-branch
export GIT_AUTHOR_NAME="Dev One" GIT_AUTHOR_EMAIL="dev.one@example.com"
export GIT_COMMITTER_NAME="Dev One" GIT_COMMITTER_EMAIL="dev.one@example.com"
at() { export GIT_AUTHOR_DATE="$1 +0530" GIT_COMMITTER_DATE="$1 +0530"; }
final=$(mktemp -d)
cp -a . "$final/"
rm -rf "$final/.eval-main"

# main: invoice list and single void.
cp -a .eval-main/. .
rm -rf .eval-main
rm -f src/lib/current-org.ts src/features/invoices/components/bulk-toolbar.tsx \
  src/features/invoices/components/invoice-summary.tsx
git init -q -b main
git add -A
at "2026-09-10T11:00:00"
git commit -q -m "feat(invoices): list and void invoices"

git checkout -q -b feat/invoice-bulk-actions
# Commit 1 on the branch: the summary card.
cp "$final/src/lib/current-org.ts" src/lib/current-org.ts
cp "$final/src/features/invoices/components/invoice-summary.tsx" src/features/invoices/components/
cp "$final/src/app/(app)/layout.tsx" "src/app/(app)/layout.tsx"
cp "$final/src/features/invoices/api.ts" src/features/invoices/api.ts
git add -A
at "2026-09-22T16:20:00"
git commit -q -m "feat(invoices): summary card for outstanding, overdue and paid"

# Commit 2 on the branch: bulk actions and export.
cp -a "$final/." .
git add -A
at "2026-09-24T18:05:00"
git commit -q -m "feat(invoices): bulk mark paid, bulk remove and CSV export

Finance asked for bulk actions on the invoice list. Adds a toolbar with
selection, Mark paid, Remove and Export CSV."
rm -rf "$final"
