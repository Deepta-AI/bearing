#!/usr/bin/env bash
# Builds this fixture's history: v2.0.0 and v2.1.0 on main; release/2.1 cut
# from v2.1.0 with one hotfix tagged v2.1.1; main then gets the hotfix
# cherry-picked and one unreleased feature. HEAD is main. The files on disk
# are the final main tree; earlier versions are written here. Removes itself.
set -euo pipefail
rm -f .eval-setup.sh .eval-branch
export GIT_AUTHOR_NAME="Dev Three" GIT_AUTHOR_EMAIL="dev.three@example.com"
export GIT_COMMITTER_NAME="Dev Three" GIT_COMMITTER_EMAIL="dev.three@example.com"
at() { export GIT_AUTHOR_DATE="$1 +0530" GIT_COMMITTER_DATE="$1 +0530"; }
final=$(mktemp -d)
cp -a . "$final/"
restore() { for p in "$@"; do cp "$final/$p" "$p"; done; }

# Before the payment_status feature (BIL-140) and before the gateway timeout.
python3 - <<'PY'
s = open('app/invoices.py').read()
open('app/invoices.py', 'w').write(s[: s.index('\n\ndef payment_status')] + '\n')
t = open('tests/test_invoices.py').read()
t = t.replace('from app.invoices import Line, invoice_total, line_total, payment_status',
              'from app.invoices import Line, invoice_total, line_total')
open('tests/test_invoices.py', 'w').write(t[: t.index('\n\ndef test_payment_status')] + '\n')
g = open('app/gateway.py').read()
open('app/gateway.py', 'w').write(g.replace('        timeout=10,\n', ''))
PY
sed -i 's/version = "2.2.0.dev0"/version = "2.0.0"/' pyproject.toml
mv migrations/0007_drop_legacy_ref.sql "$final/0007.hold"

git init -q -b main
git remote add origin git@gitlab.example.com:brightline/riverton-billing-api.git
git add -A
at "2026-05-12T12:00:00"; git commit -q -m "release: v2.0.0"
git tag -a v2.0.0 -m v2.0.0

mv "$final/0007.hold" migrations/0007_drop_legacy_ref.sql
sed -i 's/version = "2.0.0"/version = "2.1.0"/' pyproject.toml
git add -A
at "2026-07-30T17:10:00"; git commit -q -m "feat(invoices): drop the legacy ERP reference [BIL-122]"
git tag -a v2.1.0 -m v2.1.0

git checkout -q -b release/2.1
restore app/gateway.py
sed -i 's/version = "2.1.0"/version = "2.1.1"/' pyproject.toml
git add -A
at "2026-09-03T20:40:00"; git commit -q -m "fix(gateway): 10 s timeout on payment link calls [BIL-137]"
git tag -a v2.1.1 -m v2.1.1

git checkout -q main
restore app/gateway.py
git add -A
at "2026-09-04T10:15:00"; git commit -q -m "fix(gateway): 10 s timeout on payment link calls [BIL-137] (cherry picked from release/2.1)"
restore app/invoices.py tests/test_invoices.py pyproject.toml
git add -A
at "2026-09-15T16:30:00"; git commit -q -m "feat(invoices): partial payment status [BIL-140]"

git update-ref refs/remotes/origin/main main
git update-ref refs/remotes/origin/release/2.1 release/2.1
git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
rm -r "$final"
