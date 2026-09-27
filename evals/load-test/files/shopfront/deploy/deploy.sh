#!/usr/bin/env bash
# Renders deploy/<env>/values.yaml into the shared chart and applies it.
set -euo pipefail
env="${1:?usage: deploy.sh qa|production}"
helm upgrade --install shopfront platform/service -n "shopfront-$env" -f "deploy/$env/values.yaml"
