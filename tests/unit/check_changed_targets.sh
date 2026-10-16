#!/usr/bin/env bash
# tests/unit/check_changed_targets.sh: every stack Makefile template has a
# check-changed target that prints its counts, never writes .check-passed,
# and writes .check-changed-passed. Toolchain runs are in the scaffold job.
set -u
. "$(dirname "$0")/../lib/assert.sh"
n=0
seen=""
for mk in $(cd "$KIT" && git ls-files 'plugins/*/skills/*/templates*/Makefile'); do
  grep -q 'check-passed' "$KIT/$mk" || continue
  n=$((n+1))
  body="$(awk '/^check-changed:/{p=1;print;next} p&&/^[^\t]/{exit} p' "$KIT/$mk")"
  t_begin "$mk"
  assert_contains "$body" "check-changed:" "target present"
  assert_contains "$body" "0 files, nothing to check" "empty case"
  assert_contains "$body" ".check-changed-passed" "writes its own marker"
  assert_not_contains "$body" "/.check-passed" "never writes the full marker"
  assert_contains "$body" "packages checked" "prints its count"
  t_end
  seen="$seen
$(grep '^CHANGED = ' "$KIT/$mk" | md5sum | cut -d' ' -f1)"
done
t_begin "CHANGED variable identical"
assert_eq 1 "$(printf '%s\n' "$seen" | grep . | sort -u | wc -l | tr -d ' ')" "one distinct CHANGED line across $n templates"
t_end
t_begin "templates found"
assert_eq 13 "$n" "stack Makefile templates with a check marker"
t_end
t_summary
