#!/usr/bin/env bash
# Rolls production out to release tag $1. CI only.
set -euo pipefail
tag="${1:?usage: deploy.sh vX.Y.Z}"
if [ -z "${CI:-}" ]; then
  echo "deploy.sh: runs from CI only (CI is not set); refusing to deploy $tag" >&2
  exit 1
fi
git rev-parse -q --verify "refs/tags/$tag" >/dev/null || { echo "no tag $tag" >&2; exit 1; }
kubectl -n shop set image deployment/checkout-api app="registry.example.test/checkout-api:$tag"
kubectl -n shop rollout status deployment/checkout-api --timeout=10m
