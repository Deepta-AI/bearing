#!/usr/bin/env bash
# Builds this fixture's history in place: a marketing site on trunk (main
# only), recorded as a site (.bearing/config.json {"flow": "site"},
# committed with WEB-1). feature/WEB-4-Pricing is one commit ahead of
# origin/main: the page brief from brainstorming and the progress record,
# whose Next ("write the page brief") is now out of date. The local
# timeline (.bearing/state/timeline.jsonl, ignored) shows start-task and
# then brainstorming ended on this branch. No design work yet.
# Run from the fixture copy; it removes itself and its stages.
set -euo pipefail
rm -f .eval-setup.sh .eval-branch
S=.eval-stages
export GIT_AUTHOR_NAME="Dev One" GIT_AUTHOR_EMAIL="dev.one@example.com"
export GIT_COMMITTER_NAME="Dev One" GIT_COMMITTER_EMAIL="dev.one@example.com"
at() { export GIT_AUTHOR_DATE="$1 +0530" GIT_COMMITTER_DATE="$1 +0530"; }

git init -q -b main
echo "$S/" >> .git/info/exclude
git remote add origin git@gitlab.example.com:shop/shop-site.git
mkdir -p .bearing
printf '{\n  "flow": "site"\n}\n' > .bearing/config.json
git add -A
at "2026-10-02T09:40:00"; git commit -q -m "feat(site): home and about pages, recorded as a site [WEB-1]"
git update-ref refs/remotes/origin/main main
git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main

git switch -q --no-track -c feature/WEB-4-Pricing main
cp -R "$S/brief/." .
git add -A
at "2026-10-15T17:20:00"; git commit -q -m "docs(pricing): page brief and progress record [WEB-4]"

b=feature/WEB-4-Pricing
ev() { # ev <ts> <epoch> <skill> <start|end>
  printf '{"ts":"%s","epoch":%s,"session":"s-web4","branch":"%s","skill":"%s","event":"%s"}\n' "$1" "$2" "$b" "$3" "$4"
}
mkdir -p .bearing/state
{
  ev 2026-10-14T09:00:00Z 1791968400 bearing:start-task start
  ev 2026-10-14T09:05:00Z 1791968700 bearing:start-task end
  ev 2026-10-14T09:05:00Z 1791968700 superpowers:brainstorming start
  ev 2026-10-15T11:30:00Z 1792063800 superpowers:brainstorming end
} > .bearing/state/timeline.jsonl
rm -r "$S"
grep -v '^\.eval-stages/$' .git/info/exclude > .git/info/exclude.new || true
mv .git/info/exclude.new .git/info/exclude
