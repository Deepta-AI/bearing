#!/usr/bin/env bash
# tests/run.sh: run every executable test file under tests/ (unit, integration;
# not lib, not this runner). A test file that is not executable counts as a
# failure so nothing is skipped silently. Exits 1 when any test fails or when
# no test ran. bash 3.2 safe.
set -u
cd "$(dirname "$0")/.." || exit 1
n=0; failed=0
files="$(find tests -type f -name '*.sh' -not -path 'tests/lib/*' -not -name run.sh | sort)"
for f in $files; do
  n=$((n+1))
  if [ ! -x "$f" ]; then echo "FAIL $f: not executable (chmod +x)"; failed=$((failed+1)); continue; fi
  if ! bash "$f"; then echo "FAIL $f"; failed=$((failed+1)); fi
done
echo "tests: $n run, $failed failed"
[ "$n" -gt 0 ] && [ "$failed" -eq 0 ] || exit 1
