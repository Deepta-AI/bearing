#!/usr/bin/env bash
# Builds this fixture's history in place: the register seeded on
# 2026-06-03 against the old tax.py and gateway.py, then two later
# commits (tax.py changed on 2026-07-20, the gateway retry landed on
# 2026-08-10) that never touched docs/DEBT.md. The files on disk are the
# final working tree; the earlier versions are written here.
set -euo pipefail
rm -f .eval-setup.sh .eval-branch
export GIT_AUTHOR_NAME="Dev One" GIT_AUTHOR_EMAIL="dev.one@example.com"
export GIT_COMMITTER_NAME="Dev One" GIT_COMMITTER_EMAIL="dev.one@example.com"
at() { export GIT_AUTHOR_DATE="$1 +0530" GIT_COMMITTER_DATE="$1 +0530"; }
final=$(mktemp -d)
cp -a . "$final/"
restore() { for p in "$@"; do cp "$final/$p" "$p"; done; }

cat > src/invoicing/tax.py <<'EOF'
"""GST on an invoice amount."""

from decimal import Decimal


def gst(amount):
    # HACK: GST hard-coded at 18%; services at 5% and 12% are billed at 18%
    rate = Decimal("0.18")
    return (Decimal(str(amount)) * rate).quantize(Decimal("0.01"))
EOF
cat > tests/test_tax.py <<'EOF'
from decimal import Decimal

from invoicing.tax import gst


def test_gst_at_18():
    assert gst(1000) == Decimal("180.00")
EOF
cat > src/invoicing/gateway.py <<'EOF'
"""Charge a card through the payment gateway."""


def charge(client, invoice_id, amount_paise):
    key = f"invoice:{invoice_id}"
    resp = client.post("/charges", {"amount": amount_paise}, idempotency_key=key)
    # TODO: retry the gateway on 503; charges fail on every blip
    return resp
EOF
cat > tests/test_gateway.py <<'EOF'
class FakeClient:
    def __init__(self, statuses):
        self.statuses = list(statuses)

    def post(self, path, body, idempotency_key):
        return {"status": self.statuses.pop(0)}


def test_charge_succeeds():
    from invoicing.gateway import charge

    assert charge(FakeClient([200]), "INV-1", 5000)["status"] == 200
EOF

git init -q -b main
at "2026-06-03 11:00:00"
git add -A
git commit -q -m "Seed the technical debt register"

export GIT_AUTHOR_NAME="Dev Two" GIT_AUTHOR_EMAIL="dev.two@example.com"
export GIT_COMMITTER_NAME="Dev Two" GIT_COMMITTER_EMAIL="dev.two@example.com"
at "2026-07-20 16:40:00"
restore src/invoicing/tax.py tests/test_tax.py
git add -A
git commit -q -m "Support reverse-charge invoices in the GST calculation"

export GIT_AUTHOR_NAME="Dev One" GIT_AUTHOR_EMAIL="dev.one@example.com"
export GIT_COMMITTER_NAME="Dev One" GIT_COMMITTER_EMAIL="dev.one@example.com"
at "2026-08-10 10:15:00"
restore src/invoicing/gateway.py tests/test_gateway.py
git add -A
git commit -q -m "Retry the payment gateway on 503 with the same idempotency key"

rm -r "$final"
