#!/usr/bin/env bash
# Builds this fixture's history in place: main with the checkout as it was,
# the US-12-004 redesign on its feature branch, and yesterday's merge of it
# into main. Run from the fixture copy; it removes itself and .eval-prev.
set -euo pipefail
rm -f .eval-setup.sh .eval-branch
export GIT_AUTHOR_NAME="Dev One" GIT_AUTHOR_EMAIL="dev.one@example.com"
export GIT_COMMITTER_NAME="Dev One" GIT_COMMITTER_EMAIL="dev.one@example.com"
at() { export GIT_AUTHOR_DATE="$1 +0530" GIT_COMMITTER_DATE="$1 +0530"; }

final=$(mktemp -d)
cp app/cart.py app/checkout.py "$final/"
mv docs/stories "$final/stories"
cp .eval-prev/app/cart.py app/cart.py
cp .eval-prev/app/checkout.py app/checkout.py
rm -r .eval-prev

git init -q -b main
git add -A
at "2026-08-20T11:30:00"; git commit -q -m "checkout: cart, coupons, shipping and the checkout page"

git checkout -q -b feat/US-12-004-checkout-redesign
cp "$final/cart.py" app/cart.py
cp "$final/checkout.py" app/checkout.py
mv "$final/stories" docs/stories
git add -A
export GIT_AUTHOR_NAME="Dev Two" GIT_AUTHOR_EMAIL="dev.two@example.com"
at "2026-09-24T17:10:00"; git commit -q -m "feat(checkout): two-column layout, Place order CTA, free shipping nudge (US-12-004)"

git checkout -q main
export GIT_AUTHOR_NAME="Dev One" GIT_AUTHOR_EMAIL="dev.one@example.com"
at "2026-09-26T10:45:00"
git merge -q --no-ff -m "Merge branch 'feat/US-12-004-checkout-redesign' into main" feat/US-12-004-checkout-redesign
rm -r "$final"
