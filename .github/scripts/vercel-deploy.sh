#!/usr/bin/env bash
# vercel-deploy.sh <site> <dist dir>: deploy a built site folder to the
# Vercel project in VERCEL_PROJECT_ID. Refuses a folder missing its entry
# files or with no script bundles, and prints the deployed URL with the count.
set -euo pipefail
site="$1"; dist="$2"
for f in index.html 404.html robots.txt vercel.json; do
  [ -f "$dist/$f" ] || { echo "$site: $dist/$f missing, nothing deployed"; exit 1; }
done
n=$(find "$dist/assets" -name '*.js' 2>/dev/null | wc -l | tr -d ' ')
[ "$n" -gt 0 ] || { echo "$site: 0 script bundles in $dist, nothing deployed"; exit 1; }
# Say which account the token belongs to before touching the project, so a
# token scoped to the wrong team shows up as a named account, not as Vercel's
# "Could not retrieve Project Settings".
who="$(npx --yes "$VERCEL_CLI" whoami --token "$VERCEL_TOKEN" 2>/dev/null | tail -1)" || { echo "$site: VERCEL_TOKEN was rejected by Vercel; create a new token"; exit 1; }
echo "$site: token belongs to $who; deploying to project $VERCEL_PROJECT_ID in $VERCEL_ORG_ID"
cd "$dist"
if ! npx --yes "$VERCEL_CLI" pull --yes --environment=production --token "$VERCEL_TOKEN" >/dev/null; then
  echo "$site: the token ($who) cannot read that project: check the token's scope is the team that owns it, VERCEL_ORG_ID is that team, and the project id is this site's"
  exit 1
fi
url="$(npx --yes "$VERCEL_CLI" deploy --prod --yes --token "$VERCEL_TOKEN")"
echo "$site: $n script bundles deployed to $url"
