#!/usr/bin/env bash
# Deploys the current commit. Needs DEPLOY_TOKEN (a masked, protected CI
# variable in GitLab) and the environment name as the first argument.
set -euo pipefail
env="${1:?usage: deploy.sh <environment>}"
: "${DEPLOY_TOKEN:?DEPLOY_TOKEN is not set}"
sha="$(git rev-parse --short HEAD)"
echo "deploying ledger-api ${sha} to ${env}"
curl -fsS -X POST -H "Authorization: Bearer ${DEPLOY_TOKEN}" \
  "https://deploy.example.internal/api/apps/ledger-api/${env}/releases" \
  -d "{\"revision\":\"${sha}\"}"
