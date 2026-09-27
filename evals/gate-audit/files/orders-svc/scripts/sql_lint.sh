#!/usr/bin/env bash
# Reject SELECT * in the query files: list the columns you read.
set -uo pipefail
bad=0
for f in $(git ls-files 'queries/*.sql'); do
  if grep -qiE 'select[[:space:]]+\*' "$f"; then
    echo "$f: SELECT * is not allowed"
    bad=1
  fi
done
[ "$bad" -eq 0 ] && echo "sql-lint ok"
exit "$bad"
