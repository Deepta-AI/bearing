#!/usr/bin/env bash
# Pushes an env file to the checkout-api config map and restarts the pods. CI only.
set -euo pipefail
file="${1:?usage: config-apply.sh <env file>}"
if [ -z "${CI:-}" ]; then
  echo "config-apply.sh: runs from CI only (CI is not set); refusing to apply $file" >&2
  exit 1
fi
kubectl -n shop create configmap checkout-api-env --from-env-file="$file" --dry-run=client -o yaml | kubectl apply -f -
kubectl -n shop rollout restart deployment/checkout-api
