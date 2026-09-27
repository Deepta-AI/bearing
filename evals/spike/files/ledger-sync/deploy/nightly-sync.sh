#!/bin/sh
# Nightly import of bank statements. Any output on stderr means something
# went wrong that the exit code may not show (a skipped line, a driver
# warning), so it pages the on-call engineer.
set -u
db="$1"; inbox="$2"
errlog=$(mktemp)
node /app/src/cli.js sync "$db" "$inbox" 2>"$errlog"
status=$?
if [ "$status" -ne 0 ] || [ -s "$errlog" ]; then
  /app/deploy/page-oncall "ledger-sync nightly: exit $status" < "$errlog"
fi
rm -f "$errlog"
exit "$status"
