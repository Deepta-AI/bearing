#!/usr/bin/env bash
# Every up migration must ship with its down migration.
set -euo pipefail
for up in $(ls migrations/*.up.sql 2>/dev/null); do
  down="${up%.up.sql}.down.sql"
  if [ ! -f "$down" ]; then
    echo "missing down migration for $up"
    exit 1
  fi
done
echo "migrations ok"
