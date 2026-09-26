#!/usr/bin/env bash
# Builds this fixture's git history in place: main, develop one commit
# ahead (the shipping threshold change), the feature branch two commits
# ahead of develop, remote-tracking refs (main and the feature branch
# only) for an origin that is not reachable, and an uncommitted edit to
# src/shop/coupons.py. The files on disk are the final working tree; earlier versions are written here.
# Run from the fixture copy; it removes itself first.
set -euo pipefail
rm -f .eval-setup.sh .eval-branch
export GIT_AUTHOR_NAME="Dev One" GIT_AUTHOR_EMAIL="dev.one@example.com"
export GIT_COMMITTER_NAME="Dev One" GIT_COMMITTER_EMAIL="dev.one@example.com"
at() { export GIT_AUTHOR_DATE="$1 +0530" GIT_COMMITTER_DATE="$1 +0530"; }
final=$(mktemp -d)
cp -a . "$final/"
restore() { for p in "$@"; do cp "$final/$p" "$p"; done; }

# main: coupons before stacking, free shipping from Rs 500.
sed 's/FREE_SHIPPING_FROM_PAISE = 99900/FREE_SHIPPING_FROM_PAISE = 50000/' "$final/src/shop/shipping.py" > src/shop/shipping.py
cat > src/shop/coupons.py <<'EOF'
"""Coupons: one coupon per order."""

from dataclasses import dataclass

MAX_PERCENT = 50


@dataclass(frozen=True)
class Coupon:
    code: str
    kind: str  # "percent" or "flat"
    value: int  # percent, or paise for a flat coupon


def apply(subtotal_paise, coupons):
    """Return the subtotal after the first coupon, in paise."""
    if not coupons:
        return subtotal_paise
    c = coupons[0]
    if c.kind == "percent":
        return subtotal_paise - subtotal_paise * min(c.value, MAX_PERCENT) // 100
    return max(subtotal_paise - c.value, 0)
EOF
cat > src/shop/redemptions.py <<'EOF'
"""Coupon redemptions."""


def redeem(conn, customer_id, code):
    """Record a redemption."""
    with conn.cursor() as cur:
        cur.execute(
            "INSERT INTO redemptions (customer_id, code) VALUES (%s, %s)",
            (customer_id, code),
        )
EOF
cat > tests/test_coupons.py <<'EOF'
from shop.coupons import Coupon, apply


def test_tc_0230_percent_coupon():
    assert apply(100000, [Coupon("TEN", "percent", 10)]) == 90000
EOF
grep -v 'tc_0241\|percent_then_flat\|179900\|175000' "$final/tests/test_checkout.py" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' > tests/test_checkout.py
python3 - "$final/tests/integration/test_redemptions.py" <<'EOF'
import sys
s = open(sys.argv[1]).read()
start = s.index("def test_tc_0235")
end = s.index("def test_tc_0236")
open("tests/integration/test_redemptions.py", "w").write(s[:start] + s[end:])
EOF
grep -v 'TASK-377' "$final/docs/testing/quarantine.md" > docs/testing/quarantine.md

git init -q -b main
at "2026-09-01 10:00:00"
git add -A
git commit -q -m "checkout: coupons, shipping and order total"

git checkout -q -b develop
at "2026-09-10 15:20:00"
restore src/shop/shipping.py
git commit -q -am "shipping: free shipping from Rs 999"

git checkout -q -b feature/TASK-412-coupon-stacking
at "2026-09-21 11:05:00"
cp "$final/src/shop/coupons.py" src/shop/coupons.py
sed -i -e 's/^# Diwali sale: allow deeper percentage coupons.$//' -e 's/^MAX_PERCENT = 60$/MAX_PERCENT = 50/' src/shop/coupons.py
python3 - <<'EOF'
p = "src/shop/coupons.py"
s = open(p).read().replace("\n\n\nMAX_PERCENT", "\n\nMAX_PERCENT")
open(p, "w").write(s)
EOF
restore tests/test_coupons.py tests/test_checkout.py docs/testing/quarantine.md
git commit -q -am "coupons: stack flat coupons, one percentage coupon per order (TASK-412)"

at "2026-09-23 17:40:00"
restore src/shop/redemptions.py tests/integration/test_redemptions.py
git commit -q -am "redemptions: single-use coupons are redeemed once per customer (TASK-412)"

# The clone tracked main only; develop was fetched into a local branch
# (git fetch origin develop:develop), so there is no origin/develop.
git remote add origin git@gitlab.example.com:shop/shop-checkout.git
git update-ref refs/remotes/origin/main main
git update-ref refs/remotes/origin/feature/TASK-412-coupon-stacking HEAD~1

# The uncommitted edit: the Diwali cap raise, not yet committed.
restore src/shop/coupons.py
rm -r "$final"
