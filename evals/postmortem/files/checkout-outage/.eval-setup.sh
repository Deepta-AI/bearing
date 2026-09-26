#!/usr/bin/env bash
# Builds this fixture's git history in place: the service, the gift card
# release v2.2.4, the pool trim released as v2.3.0 on the incident day, the
# incident doc, the pool restore released as v2.3.1, then the incident data.
# The files on disk are the final tree; earlier versions are written here.
# Run from the fixture copy; it removes itself first.
set -euo pipefail
rm -f .eval-setup.sh .eval-branch
who() { export GIT_AUTHOR_NAME="$1" GIT_AUTHOR_EMAIL="$2" GIT_COMMITTER_NAME="$1" GIT_COMMITTER_EMAIL="$2"; }
at() { export GIT_AUTHOR_DATE="$1 +0530" GIT_COMMITTER_DATE="$1 +0530"; }
final=$(mktemp -d)
cp -a . "$final/"
restore() { for p in "$@"; do mkdir -p "$(dirname "$p")"; cp "$final/$p" "$p"; done; }

# First commit: no gift card, no incident records.
rm -r docs/postmortems
python3 - <<'PY'
import re
p = "shopfront/checkout.py"
s = open(p).read()
s = s.replace(",\n    gift_card TEXT\n", "\n")
s = s.replace(", gift_card=None", "")
s = s.replace("(customer_id, total_paise, gift_card) VALUES (?, ?, ?)", "(customer_id, total_paise) VALUES (?, ?)")
s = s.replace("(customer_id, total, gift_card)", "(customer_id, total)")
open(p, "w").write(s)
p = "tests/test_checkout.py"
s = open(p).read()
s = re.sub(r"def test_gift_card_is_stored\(\):.*?\n\n\n", "", s, flags=re.S)
open(p, "w").write(s)
PY

git init -q -b main
git remote add origin git@gitlab.example.com:shop/shopfront.git
who "Dev Two" "dev.two@example.com"
git add -A
at "2026-09-08T10:00:00"; git commit -q -m "feat: checkout service with pooled connections"

restore shopfront/checkout.py tests/test_checkout.py
git add -A
at "2026-09-15T11:00:00"; git commit -q -m "feat(checkout): optional gift card on orders [SHOP-71]"
git tag v2.2.4

who "Dev One" "dev.one@example.com"
python3 - <<'PY'
p = "shopfront/settings.py"
s = open(p).read()
s = s.replace("DB_POOL_SIZE = 20", "# Trimmed from 20: most connections sat idle overnight.\nDB_POOL_SIZE = 5")
open(p, "w").write(s)
p = "tests/test_checkout.py"
s = open(p).read()
s = s.replace("settings.DB_POOL_SIZE == 20", "settings.DB_POOL_SIZE == 5")
open(p, "w").write(s)
PY
git add -A
at "2026-09-22T13:50:00"; git commit -q -m "perf(db): trim idle connections, pool 20 -> 5 [SHOP-80]"
git tag v2.3.0

who "Dev Two" "dev.two@example.com"
restore docs/postmortems/2026-09-22-checkout-errors-incident.md
git add -A
at "2026-09-22T20:10:00"; git commit -q -m "docs: incident doc for checkout errors"

restore shopfront/settings.py tests/test_checkout.py
git add -A
at "2026-09-23T11:30:00"; git commit -q -m "fix(db): restore pool size 20 [SHOP-88]"
git tag v2.3.1

restore docs/postmortems/incident-data/5xx-by-minute.csv docs/postmortems/incident-data/chat-export.txt
git add -A
at "2026-09-23T16:00:00"; git commit -q -m "docs: incident data exports for the checkout errors"
git update-ref refs/remotes/origin/main main
rm -r "$final"
