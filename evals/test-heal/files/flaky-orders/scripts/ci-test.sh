#!/usr/bin/env bash
# CI entry point. Retries the suite because a few tests are known to be
# flaky; see docs/testing/healing-log.md.
set -uo pipefail
attempts=3
for i in $(seq 1 "$attempts"); do
  if make check; then
    exit 0
  fi
  echo "ci-test: attempt $i of $attempts failed" >&2
done
exit 1
