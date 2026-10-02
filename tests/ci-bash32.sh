#!/usr/bin/env bash
# tests/ci-bash32.sh: the bash32 CI job's body, run inside the bash:3.2 image
# (Alpine, BusyBox, no perl) by .github/workflows/ci.yml and by make ci-bash32
# on a workstation, so the job a push will run can be run before it. It runs
# every unit test file even after a failure, prints each failure, and ends
# with a count; it exits 1 on any failure or on zero files.
set -u
apk add --no-cache git make jq python3 nodejs curl grep sed coreutils findutils diffutils >/dev/null || exit 1
git config --global --add safe.directory "*"
bash --version | head -1
bash plugins/bearing/bin/brg-guard --version || exit 1
bash plugins/bearing/bin/brg-guard command "git status" || exit 1
bash plugins/bearing/bin/brg-scaffold --help >/dev/null || exit 1
bash plugins/bearing/bin/brg-adopt --help >/dev/null || exit 1
bash plugins/bearing/bin/brg-jira --help >/dev/null || exit 1
n=0; failed=0
for t in tests/unit/*.sh; do
  n=$((n+1))
  if ! bash "$t"; then echo "FAIL $t"; failed=$((failed+1)); fi
done
echo "bash32: $n unit test files, $failed failed, under $(bash --version | head -1)"
[ "$n" -gt 0 ] && [ "$failed" -eq 0 ]
