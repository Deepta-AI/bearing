#!/usr/bin/env bash
# Builds this fixture's history in place: main with the service, then a
# spike commit filed under SHOP-66 (the saved-card token charge, backlog
# CHK-6, whose backlog entry never got its key), then the backlog as
# committed, then CHK-7 added to the backlog as an uncommitted working tree
# edit (someone was still writing it). Removes itself first.
set -euo pipefail
rm -f .eval-setup.sh .eval-branch
export GIT_AUTHOR_NAME="Dev One" GIT_AUTHOR_EMAIL="dev.one@example.com"
export GIT_COMMITTER_NAME="Dev One" GIT_COMMITTER_EMAIL="dev.one@example.com"
at() { export GIT_AUTHOR_DATE="$1 +0530" GIT_COMMITTER_DATE="$1 +0530"; }
git init -q -b main
git remote add origin git@git.example.test:shop/checkout.git
tip=$(mktemp -d)
mv docs/product/backlog.md "$tip/backlog.md"
mv src/saved-cards.js test/saved-cards.test.js "$tip/"
git add -A
at "2026-09-08T10:00:00"; git commit -q -m "feat: guest checkout and hosted payment hand-off"
mv "$tip/saved-cards.js" src/saved-cards.js
mv "$tip/saved-cards.test.js" test/saved-cards.test.js
git add -A
at "2026-09-12T16:45:00"; git commit -q -m "SHOP-66: spike, charge a saved card through the provider token"
mv "$tip/backlog.md" docs/product/backlog.md
rmdir "$tip"
git add -A
at "2026-09-18T17:30:00"; git commit -q -m "docs(backlog): saved cards epic and guest stories for next sprint"

# Uncommitted: CHK-7 inserted before CHK-8.
python3 - <<'PY'
p = "docs/product/backlog.md"
s = open(p, encoding="utf-8").read()
chk7 = """### CHK-7 Remove a saved card

As a returning customer, I want to remove a card I saved, so that it can no
longer be used on my account.

- AC-7.1 Removing a card deletes our record and revokes the provider token.
- AC-7.2 A removed card no longer appears at checkout.

"""
marker = "### CHK-8 "
assert marker in s
open(p, "w", encoding="utf-8").write(s.replace(marker, chk7 + marker, 1))
PY
