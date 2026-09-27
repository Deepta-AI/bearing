#!/usr/bin/env bash
# Quick latency check with hey. Written for the 2025 launch.
set -euo pipefail
BASE_URL="${BASE_URL:-https://api.shopfront.example.net}"
KEY="${API_KEY:-dev-key-1}"
hey -z 30s -q 10 -c 5 -H "X-Api-Key: $KEY" "$BASE_URL/v1/search?q=shoes"
