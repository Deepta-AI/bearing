#!/usr/bin/env bash
# Builds this fixture's git history in place: releases v2.6.4 and v2.7.0,
# then v2.7.1 tagged 25 minutes before the run starts, then one untagged
# commit on main. Tag and commit times carry the team's +0530 offset. The
# files on disk are the final tree; earlier versions are written here. Run
# from the fixture copy; it removes itself first.
set -euo pipefail
rm -f .eval-setup.sh .eval-branch
export GIT_COMMITTER_NAME="Ben" GIT_COMMITTER_EMAIL="ben@example.test"
export GIT_AUTHOR_NAME="Ben" GIT_AUTHOR_EMAIL="ben@example.test"
at() { local s; s=$(( $(date -u +%s) - $1 * 60 )); export GIT_AUTHOR_DATE="@$s +0530" GIT_COMMITTER_DATE="@$s +0530"; }
final=$(mktemp -d)
cp -a . "$final/"
restore() { for p in "$@"; do cp "$final/$p" "$p"; done; }

# v2.7.0: the 3DS v2 flow behind CHECKOUT_3DS_V2, off by default.
sed -e 's/PAYMENTS_3DS_V2_ENABLED", "true"/CHECKOUT_3DS_V2", "false"/' "$final/app/flags.py" > app/flags.py
sed -e 's/PAYMENTS_3DS_V2_ENABLED=true/CHECKOUT_3DS_V2=false/' "$final/config/production.env" > config/production.env
sed -e 's/PAYMENTS_3DS_V2_ENABLED/CHECKOUT_3DS_V2/' "$final/tests/test_payments.py" > tests/test_payments.py
sed -e '/^## v2.7.1$/,/^## v2.7.0$/{/^## v2.7.0$/!d}' "$final/CHANGELOG.md" > CHANGELOG.md
sed -e 's/Takes card payments for the/Takes card payments for teh/' "$final/README.md" > README.md
mv docs/incidents/2026-08-12-checkout-slow.md "$final/prev-incident.md"
cp app/payments.py "$final/payments-new.py"
sed -e 's/    flow = .*/    flow = "classic"/' -e '/^from app import flags$/d' "$final/app/payments.py" > app/payments.py
sed -i -e '/test_three_ds_flag_routes/,$d' tests/test_payments.py
sed -i -e '$d' tests/test_payments.py

git init -q -b main
git add -A
at $((12 * 1440)); git commit -q -m "release: v2.6.4"; git tag -a v2.6.4 -m v2.6.4

cp "$final/payments-new.py" app/payments.py
sed -e 's/PAYMENTS_3DS_V2_ENABLED/CHECKOUT_3DS_V2/' "$final/tests/test_payments.py" > tests/test_payments.py
mkdir -p docs/incidents; cp "$final/prev-incident.md" docs/incidents/2026-08-12-checkout-slow.md
git add -A
at $((3 * 1440 + 90)); git commit -q -m "feat(payments): 3DS v2 challenge flow behind CHECKOUT_3DS_V2"
at $((3 * 1440)); git commit -q --allow-empty -m "release: v2.7.0"; git tag -a v2.7.0 -m v2.7.0

restore app/flags.py config/production.env tests/test_payments.py CHANGELOG.md
git add -A
at 40; git commit -q -m "feat(payments): 3DS v2 on by default; flag renamed to PAYMENTS_3DS_V2_ENABLED"
at 25; git commit -q --allow-empty -m "release: v2.7.1"; git tag -a v2.7.1 -m v2.7.1

restore README.md
git add -A
at 8; git commit -q -m "docs: fix a typo in the README"
rm -r "$final"
