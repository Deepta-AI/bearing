#!/usr/bin/env bash
# Builds this fixture's history in place. The files on disk are the tip of
# feature/BILL-212-invoice-export; .eval-base holds main's copy of every file
# the branch changes. main is the API as released; the branch adds two
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

# main: the released API (list, get, pay).
cp -a .eval-base/. .
rm -rf .eval-base internal/notify internal/httpapi/export.go internal/httpapi/export_test.go
git init -q -b main
git add -A
at "2026-09-10T11:00:00"; git commit -q -m "feat: invoices API (list, get, manual pay)"

# Branch commit 1: the export endpoint.
git checkout -q -b feature/BILL-212-invoice-export
for f in internal/invoice/invoice.go internal/invoice/invoice_test.go internal/store/invoices.go \
  internal/httpapi/server.go internal/httpapi/fake_test.go internal/httpapi/export.go \
  internal/httpapi/export_test.go docs/api.md; do
  cp "$tip/$f" "$f"
done
# The notifier arrives in commit 2; commit 1 builds without it.
sed -i -e '/internal\/notify"/d' -e '/Notify   notify.Notifier/d' internal/httpapi/server.go
sed -i -e '/Notify:   &fakeNotifier{},/d' internal/httpapi/fake_test.go
sed -i -e '/if s.Notify != nil {/,/^\t}$/d' internal/httpapi/export.go
git add -A
at "2026-09-23T15:20:00"; git commit -q -m "feat(invoices): CSV export for the dashboard download (BILL-212)"

# Branch commit 2: tell the merchant when an export is ready.
cp -a "$tip/internal/notify" internal/
for f in internal/httpapi/server.go internal/httpapi/fake_test.go internal/httpapi/export.go cmd/api/main.go; do
  cp "$tip/$f" "$f"
done
git add -A
at "2026-09-25T12:05:00"; git commit -q -m "feat(invoices): notify the merchant when an export is ready, when NOTIFY_URL is set (BILL-212)"
rm -rf "$tip"
