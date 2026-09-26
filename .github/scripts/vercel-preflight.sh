#!/usr/bin/env bash
# vercel-preflight.sh <site> <project secret name>: check the Vercel secrets
# before a deploy. Writes ready=true|false to $GITHUB_OUTPUT. Missing secrets
# are a skip with a note (a fork has none); a secret in the wrong shape fails,
# because Vercel only says "Could not retrieve Project Settings".
set -euo pipefail
site="$1"; secret="$2"
missing=""
[ -n "${VERCEL_TOKEN:-}" ] || missing="$missing VERCEL_TOKEN"
[ -n "${VERCEL_ORG_ID:-}" ] || missing="$missing VERCEL_ORG_ID"
[ -n "${VERCEL_PROJECT_ID:-}" ] || missing="$missing $secret"
if [ -n "$missing" ]; then
  echo "$site: not deployed, repository secrets not set:$missing"
  echo "ready=false" >> "${GITHUB_OUTPUT:-/dev/null}"
  exit 0
fi
bad=0
for v in VERCEL_TOKEN VERCEL_ORG_ID VERCEL_PROJECT_ID; do
  case "${!v}" in *[[:space:]]*) echo "$site: $v contains whitespace or a line break; set it again"; bad=$((bad+1));; esac
done
case "$VERCEL_ORG_ID" in team_*) ;; *) echo "$site: VERCEL_ORG_ID should start with team_"; bad=$((bad+1));; esac
case "$VERCEL_PROJECT_ID" in prj_*) ;; *) echo "$site: $secret should start with prj_"; bad=$((bad+1));; esac
[ "$bad" -eq 0 ] || { echo "$site: 3 secrets checked, $bad wrong; nothing deployed"; exit 1; }
echo "$site: 3 secrets checked, 0 wrong"
echo "ready=true" >> "${GITHUB_OUTPUT:-/dev/null}"
