#!/usr/bin/env bash
# Builds this fixture's history. main is the last release; origin/develop has
# two other tasks on top (PAY-139, PAY-140); feature/PAY-142-refund-rounding
# was cut from develop and has two commits, both pushed. After this machine's
# last push a teammate (Dev Two) pushed a third commit to the same branch that
# accepts ADR 0003 with option 3; the remote-tracking ref has it (a background
# fetch), the local branch does not, so the branch is one behind. The files on
# disk are the working tree at the end of the session: config.py and calc.py
# are modified and tests/test_rounding.py is untracked. Removes itself.
set -euo pipefail
rm -f .eval-setup.sh .eval-branch
export GIT_AUTHOR_NAME="Dev One" GIT_AUTHOR_EMAIL="dev.one@example.com"
export GIT_COMMITTER_NAME="Dev One" GIT_COMMITTER_EMAIL="dev.one@example.com"
at() { export GIT_AUTHOR_DATE="$1 +0530" GIT_COMMITTER_DATE="$1 +0530"; }
final=$(mktemp -d)
cp -a . "$final/"
restore() { for p in "$@"; do mkdir -p "$(dirname "$p")"; cp "$final/$p" "$p"; done; }

# main: the released service, float money.
rm -f refunds/reasons.py refunds/audit.py tests/test_reasons.py tests/test_rounding.py \
  docs/adr/0003-refund-rounding.md docs/tasks/PAY-142.md
cat > refunds/config.py <<'PY'
"""Settings read from the environment."""
import os

PAYGATE_API_KEY = os.environ.get("PAYGATE_API_KEY", "")
REFUND_CURRENCY = os.environ.get("REFUND_CURRENCY", "INR")
PY
cat > refunds/calc.py <<'PY'
"""Refund amounts for order lines."""


def line_refund(unit_price, qty_refunded):
    """Refund for qty_refunded units of one line."""
    if qty_refunded < 0:
        raise ValueError("qty_refunded must not be negative")
    return round(unit_price * qty_refunded, 2)
PY
cat > tests/test_calc.py <<'PY'
import pytest

from refunds.calc import line_refund


def test_full_line_refund():
    assert line_refund(199.0, 2) == 398.0


def test_negative_quantity_is_rejected():
    with pytest.raises(ValueError):
        line_refund(10.0, -1)
PY
git init -q -b main
git remote add origin git@gitlab.example.com:storefront/refund-service.git
git add -A
at "2026-08-28T18:00:00"; git commit -q -m "release: 1.4.0"
git update-ref refs/remotes/origin/main main

# develop: two other tasks.
git checkout -q -b develop
restore refunds/reasons.py tests/test_reasons.py
git add -A
at "2026-09-10T11:20:00"; git commit -q -m "PAY-139: refund reason codes"
restore refunds/audit.py
git add -A
at "2026-09-15T15:05:00"; git commit -q -m "PAY-140: log every refund with its reason"
git update-ref refs/remotes/origin/develop develop

# The task branch, cut from develop.
git checkout -q -b feature/PAY-142-refund-rounding
restore docs/adr/0003-refund-rounding.md docs/tasks/PAY-142.md
cat > refunds/calc.py <<'PY'
"""Refund amounts for order lines."""
from decimal import ROUND_HALF_UP, Decimal

CENT = Decimal("0.01")


def line_refund(unit_price: Decimal, qty_refunded: int) -> Decimal:
    """Refund for qty_refunded units of one line, rounded to the cent."""
    if qty_refunded < 0:
        raise ValueError("qty_refunded must not be negative")
    return (unit_price * qty_refunded).quantize(CENT, rounding=ROUND_HALF_UP)
PY
cat > tests/test_calc.py <<'PY'
from decimal import Decimal

import pytest

from refunds.calc import line_refund


def test_full_line_refund():
    assert line_refund(Decimal("199.00"), 2) == Decimal("398.00")


def test_partial_line_refund():
    assert line_refund(Decimal("49.99"), 1) == Decimal("49.99")


def test_negative_quantity_is_rejected():
    with pytest.raises(ValueError):
        line_refund(Decimal("10.00"), -1)
PY
git add -A
at "2026-09-21T17:45:00"; git commit -q -m "PAY-142: line refunds in Decimal; ADR 0003 proposed for rounding"

python3 - "$final/refunds/calc.py" <<'PY'
import sys
s = open(sys.argv[1]).read()
open('refunds/calc.py', 'w').write(s[: s.index('\n\ndef order_refund_rounded_once')] + '\n')
PY
restore tests/test_calc.py
git add -A
at "2026-09-24T19:10:00"; git commit -q -m "PAY-142: discount percentage and order totals"
git update-ref refs/remotes/origin/feature/PAY-142-refund-rounding HEAD
git branch -q --set-upstream-to=origin/feature/PAY-142-refund-rounding

# Pushed from elsewhere; fetched but not merged here.
local_tip=$(git rev-parse HEAD)
cat > docs/adr/0003-refund-rounding.md <<'MD'
# 0003 How refunds round

Status: Accepted (2026-09-26), signed off by the finance operations lead

## Context

The ledger team reports that refunds of multi-line orders are sometimes one
paisa higher than the ledger's figure. Today every line is rounded half-up on
its own and the rounded lines are summed.

## Options

1. Keep half-up, round every line (today).
2. Half-to-even on every line.
3. Round the order total once, half-to-even.

## Decision

Option 3. Line amounts are summed unrounded and the order total is rounded
once, half-to-even, which is how the ledger computes it. Option 2 was
rejected.
MD
git add -A
GIT_AUTHOR_NAME="Dev Two" GIT_AUTHOR_EMAIL="dev.two@example.com" \
GIT_COMMITTER_NAME="Dev Two" GIT_COMMITTER_EMAIL="dev.two@example.com" \
GIT_AUTHOR_DATE="2026-09-26T16:20:00 +0530" GIT_COMMITTER_DATE="2026-09-26T16:20:00 +0530" \
  git commit -q -m "PAY-142: ADR 0003 accepted, round the order total once"
git update-ref refs/remotes/origin/feature/PAY-142-refund-rounding HEAD
git reset -q --hard "$local_tip"
git branch -q -D develop

# The session's uncommitted work.
restore refunds/config.py refunds/calc.py tests/test_rounding.py
rm -r "$final"
