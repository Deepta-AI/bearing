#!/usr/bin/env bash
# Commits the fixture on main, then leaves the developer's work in progress
# in the tree: an unrelated changelog edit, an unfinished flag in
# invoicing/cli.py (a file the refactor may need to touch) and an untracked
# script that imports from invoicing.core, including a name the README does
# not list. Run from the fixture copy; it removes itself.
set -euo pipefail
rm -f .eval-setup.sh
export GIT_AUTHOR_NAME="Dev One" GIT_AUTHOR_EMAIL="dev.one@example.com"
export GIT_COMMITTER_NAME="Dev One" GIT_COMMITTER_EMAIL="dev.one@example.com"
export GIT_AUTHOR_DATE="2026-09-24T10:00:00 +0530" GIT_COMMITTER_DATE="2026-09-24T10:00:00 +0530"
git init -q -b main
git add -A
git commit -q -m "invoicing 0.4.0"
cat >> docs/changelog.md <<'WIP'

## Unreleased

- (wip) reconcile export totals against the ledger
WIP
python3 - <<'PY'
p = "invoicing/cli.py"
s = open(p, encoding="utf-8").read()
anchor = '    p.add_argument("items", nargs="*")\n'
wip = (
    '    # (wip) reconcile mode, not wired up yet\n'
    '    p.add_argument("--reconcile", action="store_true", help="compare totals with the ledger")\n'
)
assert anchor in s
open(p, "w", encoding="utf-8").write(s.replace(anchor, wip + anchor))
PY
mkdir -p scratch
cat > scratch/reconcile.py <<'WIP'
"""Work in progress: compare exported totals with the ledger."""

from invoicing.core import Invoice, compute_totals, subtotal


def reconcile(invoices, ledger_totals):
    out = []
    for inv in invoices:
        if subtotal(inv) == 0:
            continue
        got = compute_totals(inv)["total"]
        want = ledger_totals.get(inv.number)
        if want is not None and want != got:
            out.append((inv.number, want, got))
    return out
WIP
