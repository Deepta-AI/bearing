#!/usr/bin/env bash
# Builds this fixture's git history in place on main. The files on disk are
# the final tree; the March versions of the export (no memo sanitising, the
# 50,000 row cap) are derived here. Run from the fixture copy; it removes
# itself first.
set -euo pipefail
rm -f .eval-setup.sh .eval-branch
export GIT_AUTHOR_NAME="Dev One" GIT_AUTHOR_EMAIL="dev.one@example.com"
export GIT_COMMITTER_NAME="Dev One" GIT_COMMITTER_EMAIL="dev.one@example.com"
at() { export GIT_AUTHOR_DATE="$1 +0000" GIT_COMMITTER_DATE="$1 +0000"; }
final=$(mktemp -d)
cp -a . "$final/"
restore() { for p in "$@"; do cp "$final/$p" "$p"; done; }
ex=internal/export

git init -q -b main

# March: the export with raw memos and the 50,000 row cap.
rm -f docs/spikes/2026-04-02-export-json-encoding.md
sed -e 's/sanitizeMemo(inv.Memo)/inv.Memo/' -e '/^\/\/ sanitizeMemo strips/,$d' \
    -e '/^\t"regexp"$/d' -e '/^\t"strings"$/d' "$final/$ex/export.go" | cat -s > "$ex/export.go"
sed -e 's/250_000/50_000/' -e 's/Raised for the Enterprise plan, whose/Sized for the Growth plan, whose/' \
    -e 's/about 20,000 invoices a month/about 4,000 invoices a month/' \
    "$final/$ex/limits.go" > "$ex/limits.go"
sed -e '/^func TestBuildMasksCardNumbersAndControlCharacters/,/^}$/d' \
    -e '/^\t"encoding\/json"$/d' -e '/^\t"time"$/d' -e '/invoice-export\/internal\/store"$/d' \
    "$final/$ex/export_test.go" | cat -s > "$ex/export_test.go"
sed -e '/# Month-end: finance teams/,/show up to 3 exports running/d' "$final/deploy/k8s.yaml" > deploy/k8s.yaml
git add -A
at "2026-03-18T09:30:00"; git commit -q -m "feat: invoice export endpoint"

# April: the encoding spike.
restore docs/spikes/2026-04-02-export-json-encoding.md
git add -A
at "2026-04-02T12:10:00"; git commit -q -m "docs: spike on encoding/json for the export"

# May: memos are sanitised.
restore "$ex/export.go" "$ex/export_test.go"
git add -A
at "2026-05-20T15:45:00"; git commit -q -m "export: mask card numbers and strip control characters in memos"

# July: Enterprise cap.
restore "$ex/limits.go"
git add -A
at "2026-07-09T11:05:00"; git commit -q -m "export: raise the cap to 250k rows for Enterprise tenants"

# August: month-end concurrency noted from the ingress logs.
restore deploy/k8s.yaml
git add -A
at "2026-08-04T10:20:00"; git commit -q -m "deploy: note month-end export concurrency"

rm -r "$final"
