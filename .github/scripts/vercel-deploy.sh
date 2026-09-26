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
cd "$dist"
npx --yes "$VERCEL_CLI" pull --yes --environment=production --token "$VERCEL_TOKEN" >/dev/null
url="$(npx --yes "$VERCEL_CLI" deploy --prod --yes --token "$VERCEL_TOKEN")"
echo "$site: $n script bundles deployed to $url"
