#!/bin/sh
# Offline stand-in for the storefront gate: every source file is present
# and exports something. CI runs the full type check and build.
set -eu
n=0
for f in src/*.ts; do
  grep -q '^export ' "$f" || { echo "check: $f exports nothing"; exit 1; }
  n=$((n+1))
done
[ "$n" -gt 0 ] || { echo "check: 0 source files, nothing checked"; exit 1; }
echo "check: $n source files"
