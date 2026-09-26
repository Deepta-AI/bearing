#!/usr/bin/env bash
# Builds this fixture's git history in place: releases v2.6.4, v2.7.0 and
# v2.7.1 (tagged at 08:24Z today, the release the incident rolled back),
# an untagged README commit, and the live incident doc, dated today (UTC).
# Commit and tag times carry the team's +0530 offset. The files on disk are
# the final tree; earlier versions are written here. Run from the fixture
# copy; it removes itself first.
set -euo pipefail
rm -f .eval-setup.sh .eval-branch
export GIT_COMMITTER_NAME="Ben" GIT_COMMITTER_EMAIL="ben@example.test"
export GIT_AUTHOR_NAME="Ben" GIT_AUTHOR_EMAIL="ben@example.test"
today=$(date -u +%F)
day() { date -u -d "$today $1 days" +%F; }
at() { export GIT_AUTHOR_DATE="$1 +0530" GIT_COMMITTER_DATE="$1 +0530"; }
final=$(mktemp -d)
cp -a . "$final/"
restore() { for p in "$@"; do cp "$final/$p" "$p"; done; }
doc=docs/incidents/INCIDENT-DATE-checkout-payments-failing.md
rm "$doc"

# v2.7.0: the 3DS v2 flow behind CHECKOUT_3DS_V2, off by default.
sed -e 's/PAYMENTS_3DS_V2_ENABLED", "true"/CHECKOUT_3DS_V2", "false"/' "$final/app/flags.py" > app/flags.py
sed -e 's/PAYMENTS_3DS_V2_ENABLED=true/CHECKOUT_3DS_V2=false/' "$final/config/production.env" > config/production.env
sed -e 's/PAYMENTS_3DS_V2_ENABLED/CHECKOUT_3DS_V2/' "$final/tests/test_payments.py" > tests/test_payments.py
sed -e '/^## v2.7.1$/,/^## v2.7.0$/{/^## v2.7.0$/!d}' "$final/CHANGELOG.md" > CHANGELOG.md
sed -e 's/Takes card payments for the/Takes card payments for teh/' "$final/README.md" > README.md
mv docs/incidents/2026-08-12-checkout-slow.md "$final/prev-incident.md"
sed -e 's/    flow = .*/    flow = "classic"/' -e '/^from app import flags$/d' "$final/app/payments.py" > app/payments.py
sed -i -e '/test_three_ds_flag_routes/,$d' tests/test_payments.py
sed -i -e '$d' tests/test_payments.py

git init -q -b main
git add -A
at "$(day -12)T12:30:00"; git commit -q -m "release: v2.6.4"; git tag -a v2.6.4 -m v2.6.4

restore app/payments.py
sed -e 's/PAYMENTS_3DS_V2_ENABLED/CHECKOUT_3DS_V2/' "$final/tests/test_payments.py" > tests/test_payments.py
mkdir -p docs/incidents; cp "$final/prev-incident.md" docs/incidents/2026-08-12-checkout-slow.md
git add -A
at "$(day -3)T11:20:00"; git commit -q -m "feat(payments): 3DS v2 challenge flow behind CHECKOUT_3DS_V2"
at "$(day -3)T12:40:00"; git commit -q --allow-empty -m "release: v2.7.0"; git tag -a v2.7.0 -m v2.7.0

restore app/flags.py config/production.env tests/test_payments.py CHANGELOG.md
git add -A
at "${today}T13:30:00"; git commit -q -m "feat(payments): 3DS v2 on by default; flag renamed to PAYMENTS_3DS_V2_ENABLED"
at "${today}T13:50:00"; git commit -q --allow-empty -m "release: v2.7.1"; git tag -a v2.7.1 -m v2.7.1

restore README.md
git add -A
at "${today}T14:05:00"; git commit -q -m "docs: fix a typo in the README"

sed -e "s/INCIDENT-DATE/$today/g" "$final/$doc" > "docs/incidents/$today-checkout-payments-failing.md"
git add -A
at "${today}T14:48:00"; git commit -q -m "docs: incident doc, checkout card payments failing"
rm -r "$final"
