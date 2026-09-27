#!/usr/bin/env bash
# Restore the latest nightly dump.
# Usage: scripts/restore.sh [target-database-url]   (defaults to DATABASE_URL from .env)
set -euo pipefail
cd "$(dirname "$0")/.."
[ -f .env ] && . ./.env

TARGET="${1:-$DATABASE_URL}"
latest=$(aws s3 ls "$BACKUP_BUCKET/" | sort | tail -n 1 | awk '{print $4}')
echo "restoring $latest into $TARGET"
aws s3 cp "$BACKUP_BUCKET/$latest" /tmp/restore.dump
pg_restore --clean --if-exists --no-owner -j 4 -d "$TARGET" /tmp/restore.dump
echo "restore finished"
