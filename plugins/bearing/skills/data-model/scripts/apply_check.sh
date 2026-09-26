#!/usr/bin/env bash
# apply_check.sh: prove a schema.sql applies to an empty PostgreSQL.
#
# Starts a throwaway postgres container, runs the file with ON_ERROR_STOP in a
# single transaction and removes the container. Nothing is published on a
# port and no shared database is touched. Docker absent or its daemon down
# prints SKIPPED and exits 0: the stdlib gate (model_check.py) still ran, and
# a skipped proof is said, never passed off as a pass.
#
# Usage: apply_check.sh [schema.sql] [image]
#   defaults: docs/design/schema.sql, postgres:16
# Prints one line: "schema-apply: <file> applied to <image>, N tables" or the
# psql error; exits 1 when the file is missing, empty, or fails to apply.
# bash 3.2 safe.
set -u
file="${1:-docs/design/schema.sql}"
image="${2:-postgres:16}"

if [ ! -s "$file" ]; then
  echo "schema-apply: $file is missing or empty, nothing applied"
  exit 1
fi
if ! command -v docker >/dev/null 2>&1; then
  echo "schema-apply: SKIPPED (docker not available)"
  exit 0
fi
if ! docker info >/dev/null 2>&1; then
  echo "schema-apply: SKIPPED (docker daemon not reachable)"
  exit 0
fi

# initdb and a socket-only server inside the container, then the file on
# stdin. The file carries its own BEGIN and COMMIT; ON_ERROR_STOP makes the
# first error fatal, so a failed statement leaves nothing half applied.
script='set -e
initdb -D /tmp/pg -A trust >/dev/null
pg_ctl -D /tmp/pg -o "-c listen_addresses=" -w start >/dev/null
psql -X -q -v ON_ERROR_STOP=1 -d postgres -f -
psql -X -At -d postgres -c "select count(*) from pg_tables where schemaname = current_schema()"'

out="$(docker run --rm -i --user postgres --entrypoint bash "$image" -c "$script" < "$file" 2>&1)"
rc=$?
tables="$(printf '%s\n' "$out" | tail -1)"
errors="$(printf '%s\n' "$out" | grep -E 'ERROR|FATAL' || true)"
if [ "$rc" -ne 0 ] || [ -n "$errors" ]; then
  printf '%s\n' "$out" | grep -v '^[0-9]*$' | head -20
  echo "schema-apply: $file failed to apply to $image"
  exit 1
fi
case "$tables" in
  ''|*[!0-9]*) echo "$out" | head -20; echo "schema-apply: could not count tables in $image"; exit 1 ;;
esac
if [ "$tables" -eq 0 ]; then
  echo "schema-apply: $file applied to $image but created 0 tables"
  exit 1
fi
echo "schema-apply: $file applied to $image, $tables tables"
