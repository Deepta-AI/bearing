#!/bin/sh
# Offline gate: every page under src/app has a default export and one h1.
# CI also runs the type check and next build.
set -eu
n=0
for f in $(find src/app -name page.tsx | sort); do
  grep -q '^export default function' "$f" || { echo "check: $f has no default export"; exit 1; }
  [ "$(grep -c '<h1>' "$f")" -eq 1 ] || { echo "check: $f needs exactly one h1"; exit 1; }
  n=$((n+1))
done
[ "$n" -gt 0 ] || { echo "check: 0 pages, nothing checked"; exit 1; }
echo "check: $n pages"
