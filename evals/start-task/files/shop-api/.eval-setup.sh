#!/usr/bin/env bash
# Builds two repositories of one project side by side: this one (ShopApi,
# the server) and its sibling ../ShopWeb (the storefront, the client),
# moved out of .eval-sibling/ and given its own history. Each has main and
# develop, with origin/main and origin/develop as remote-tracking refs for
# an origin that is not reachable; each has develop checked out, clean.
# docs/architecture/repo-plan.json lists ShopWeb first and ShopApi (path
# ".") second; by git_path group the server merges before the client.
# Run from the fixture copy; it removes itself first.
set -euo pipefail
rm -f .eval-setup.sh .eval-branch
export GIT_AUTHOR_NAME="Dev One" GIT_AUTHOR_EMAIL="dev.one@example.com"
export GIT_COMMITTER_NAME="Dev One" GIT_COMMITTER_EMAIL="dev.one@example.com"
at() { export GIT_AUTHOR_DATE="$1 +0530" GIT_COMMITTER_DATE="$1 +0530"; }

# build_history <origin url> <first subject> <develop subject>: main, then
# develop one commit ahead, both as origin's, develop checked out.
build_history() {
  git init -q -b main
  git remote add origin "$1"
  git add -A
  at "2026-10-01T10:00:00"; git commit -q -m "$2"
  git update-ref refs/remotes/origin/main main
  git switch -q -c develop
  printf '\nOwners: the shop team.\n' >> README.md
  git add -A
  at "2026-10-08T12:15:00"; git commit -q -m "$3"
  git update-ref refs/remotes/origin/develop develop
  git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
}

parent="$(cd .. && pwd)"
rm -rf "$parent/ShopWeb"
mv .eval-sibling/ShopWeb "$parent/ShopWeb"
rmdir .eval-sibling

build_history git@gitlab.example.com:shop/shop-api.git \
  "feat(orders): orders with integer paise totals [SHOP-1]" "docs: owners [SHOP-2]"
(cd "$parent/ShopWeb" && build_history git@gitlab.example.com:shop/shop-web.git \
  "feat(money): format paise from the order API [SHOP-3]" "docs: owners [SHOP-4]")
