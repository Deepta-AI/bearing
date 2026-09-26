#!/usr/bin/env bash
# Builds this fixture's git history in place: main and develop, the
# feature branch under test three commits ahead of develop, remote-tracking
# refs for an origin that is not reachable, and an uncommitted README edit.
# The files on disk are the final working tree; earlier versions are
# written here. Run from the fixture copy; it removes itself first.
set -euo pipefail
rm -f .eval-setup.sh .eval-branch
export GIT_AUTHOR_NAME="Dev One" GIT_AUTHOR_EMAIL="dev.one@example.com"
export GIT_COMMITTER_NAME="Dev One" GIT_COMMITTER_EMAIL="dev.one@example.com"
at() { export GIT_AUTHOR_DATE="$1 +0530" GIT_COMMITTER_DATE="$1 +0530"; }
final=$(mktemp -d)
cp -a . "$final/"
restore() { for p in "$@"; do cp "$final/$p" "$p"; done; }

# Base versions of the files the later commits change.
grep -v 'REFUND_' "$final/README.md" > README.md
grep -v 'refund_' "$final/src/payments/config.py" > src/payments/config.py
cat > src/payments/refunds.py <<'EOF'
"""Refunds against the card gateway."""


def refund(gateway, order_id, amount_paise):
    if amount_paise <= 0:
        raise ValueError("refund amount must be positive")
    return gateway.refund(order_id, amount_paise, idempotency_key=f"refund:{order_id}")
EOF
cat > src/payments/ledger.py <<'EOF'
"""An append-only ledger of money movements."""

from dataclasses import dataclass


@dataclass(frozen=True)
class Entry:
    order_id: str
    kind: str
    amount_paise: int


class Ledger:
    def __init__(self):
        self.entries = []

    def record(self, order_id, kind, amount_paise):
        self.entries.append(Entry(order_id, kind, amount_paise))

    def balance(self, order_id):
        total = 0
        for e in self.entries:
            if e.order_id == order_id:
                total += e.amount_paise if e.kind == "capture" else -e.amount_paise
        return total
EOF
cat > tests/test_ledger.py <<'EOF'
from payments.ledger import Ledger


def test_balance_nets_refunds():
    l = Ledger()
    l.record("o1", "capture", 5000)
    l.record("o1", "refund", 1500)
    assert l.balance("o1") == 3500
EOF
cat > tests/test_refunds.py <<'EOF'
import pytest

from payments.refunds import refund


class FakeGateway:
    def __init__(self):
        self.calls = []

    def refund(self, order_id, amount_paise, idempotency_key):
        self.calls.append(idempotency_key)
        return {"status": "refunded", "order_id": order_id}


def test_refund_sends_order_key():
    gw = FakeGateway()
    assert refund(gw, "o1", 1500)["status"] == "refunded"
    assert gw.calls == ["refund:o1"]


def test_rejects_non_positive_amount():
    with pytest.raises(ValueError):
        refund(FakeGateway(), "o1", 0)
EOF

git init -q -b main
git remote add origin git@gitlab.example.com:shop/payments-service.git
git add -A
at "2026-09-01T10:00:00"; git commit -q -m "chore: payments service with refunds and ledger [PAY-101]"
git update-ref refs/remotes/origin/main main
git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main

git checkout -q -b develop
restore src/payments/ledger.py tests/test_ledger.py
git add -A
at "2026-09-10T15:20:00"; git commit -q -m "feat(ledger): export entries as CSV [PAY-180]"
git update-ref refs/remotes/origin/develop develop

git checkout -q -b feature/PAY-214-refund-retry
restore src/payments/config.py src/payments/refunds.py
git add -A
at "2026-09-22T11:05:00"; git commit -q -m "feat(refunds): retry gateway timeouts with backoff [PAY-214]"

sed -e 's/, sleep=no_sleep//' -e '/^def no_sleep/,/^    pass$/d' "$final/tests/test_refunds.py" > tests/test_refunds.py
git add -A
at "2026-09-23T16:40:00"; git commit -q -m "test(refunds): cover retries and give-up [PAY-214]"

restore tests/test_refunds.py
git add -A
at "2026-09-24T18:12:00"; git commit -q -F - <<'EOF'
fix tests

Use a no-op sleep so the suite does not wait on the backoff.

Co-Authored-By: AI Assistant <ai-assistant@noreply.example.com>
EOF

# Left uncommitted: the README rows for the two new variables.
restore README.md
rm -r "$final"
