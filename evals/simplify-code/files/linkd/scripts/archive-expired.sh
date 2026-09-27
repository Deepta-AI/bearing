#!/usr/bin/env bash
# Nightly, from ops/crontab: append the links that expired to the audit
# archive finance keeps (archive/expired-YYYY-MM-DD.jsonl).
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p archive
./linkd -data "${LINKD_DATA:-/var/lib/linkd/links.json}" -export-expired > "archive/expired-$(date +%F).jsonl"
