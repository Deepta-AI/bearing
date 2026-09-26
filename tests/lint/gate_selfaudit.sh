#!/usr/bin/env bash
# tests/lint/gate_selfaudit.sh: every gate the kit ships obeys the gate rule:
# it prints the count of what it checked and fails when that count is zero.
# The kit's own Makefile and every stack template Makefile are read. The
# gates of a check target are its prerequisites plus the words of GATES.
# For each gate the recipe lines are extracted (a recipe that only delegates
# to "bash <script>" or "python3 <script>.py" is judged by that script) and must hold both a count
# line (an echo of "<gate>: ..." carrying a shell variable, a number or the
# word checked) and an empty-input guard (-gt 0, -eq <n>, "nothing checked",
# "is empty", or a build gate's missing-artifact exit). Every stack Makefile
# must also define skip, handle
# BEARING_ALLOW_SKIP and print the "gates run" tally. Counts are printed and the
# test fails when zero Makefiles or zero gates were audited.
set -u
. "$(dirname "$0")/../lib/assert.sh"

COUNT_RE='echo "[a-z_-]+: [^"]*(\$\$?\{?[a-z_]+|[0-9]+|checked)'
# A build gate's empty input is a missing artifact: "[ -f X ] || { echo missing; exit 1; }" counts.
GUARD_RE='-gt 0|-eq [1-9]|nothing checked|is empty|missing" >&2; exit 1'
TAB="$(printf '\t')"

# recipe <makefile> <target>: the tab-indented lines under "<target>:".
recipe() { awk -v t="$2" 'BEGIN {on=0} $0 ~ ("^" t ":") {on=1; next} on && /^\t/ {print; next} on {exit}' "$1"; }
# gates_of <makefile>: check's prerequisites, then the GATES variable's words.
gates_of() {
  { sed -n 's/^check:\([^#]*\).*/\1/p' "$1"; sed -n 's/^GATES *:= *\(.*\)$/\1/p' "$1"; } | tr ' \t' '\n\n' | grep -v '^$' | sort -u
}
# audit_gate <makefile> <gate>: the count and guard assertions on one gate.
audit_gate() {
  local mk="$1" g="$2" text script pyscript
  text="$(recipe "$mk" "$g")"
  assert_eq 1 "$([ -n "$text" ] && echo 1)" "$mk: gate '$g' has a recipe"
  # A one-line delegation to a script: judge the script.
  script="$(printf '%s\n' "$text" | sed -n -E "1s/^${TAB}@?bash ([^ ]+)\$/\\1/p")"
  pyscript="$(printf '%s\n' "$text" | sed -n -E "1s/^${TAB}@?python3 ([^ ]+\\.py)\$/\\1/p")"
  if [ -n "$script" ] && [ "$(printf '%s\n' "$text" | wc -l | tr -d ' ')" -eq 1 ]; then
    text="$(cat "$(dirname "$mk")/$script")"
    COUNT_RE_USED='echo "[a-z_-]+: [^"]*(\$\{?[a-z_]+|[0-9]+|checked)'
  elif [ -n "$pyscript" ] && [ "$(printf '%s\n' "$text" | wc -l | tr -d ' ')" -eq 1 ]; then
    # A Python gate: an f-string count line "<gate>: {n} ..." and a
    # "nothing checked" exit on empty input, judged in the script.
    text="$(cat "$(dirname "$mk")/$pyscript")"
    COUNT_RE_USED='f"[a-z_-]+: [^"]*\{[a-z_]+'
  else
    COUNT_RE_USED="$COUNT_RE"
  fi
  assert_eq 1 "$(printf '%s\n' "$text" | grep -Eq -e "$COUNT_RE_USED" && echo 1)" "$mk: gate '$g' prints a count line"
  assert_eq 1 "$(printf '%s\n' "$text" | grep -Eq -e "$GUARD_RE" && echo 1)" "$mk: gate '$g' guards empty input"
}

makefiles=0; gates=0

t_begin "kit Makefile"
mk="$KIT/Makefile"
makefiles=$((makefiles+1))
kit_gates="$(gates_of "$mk")"
assert_eq 1 "$([ -n "$kit_gates" ] && echo 1)" "check has prerequisites"
for g in $kit_gates; do gates=$((gates+1)); audit_gate "$mk" "$g"; done
assert_contains " $(printf '%s' "$kit_gates" | tr '\n' ' ') " " test " "the test suite is a gate of check"
assert_contains " $(printf '%s' "$kit_gates" | tr '\n' ' ') " " lint-shell " "lint-shell is a gate of check"
t_end

for mk in "$KIT"/plugins/*/skills/*/templates*/Makefile; do
  [ -f "$mk" ] || continue
  rel="${mk#"$KIT"/}"
  makefiles=$((makefiles+1))
  t_begin "$rel"
  stack_gates="$(gates_of "$mk")"
  assert_eq 1 "$([ -n "$stack_gates" ] && echo 1)" "$rel: GATES is set"
  ng=0
  for g in $stack_gates; do gates=$((gates+1)); ng=$((ng+1)); audit_gate "$mk" "$g"; done
  assert_eq 1 "$([ "$ng" -ge 3 ] && echo 1)" "$rel: at least three gates ($ng)"
  assert_eq 1 "$(grep -q '^define skip$' "$mk" && echo 1)" "$rel: defines skip"
  assert_eq 1 "$(grep -q 'BEARING_ALLOW_SKIP' "$mk" && echo 1)" "$rel: handles BEARING_ALLOW_SKIP"
  assert_eq 1 "$(grep -q 'gates run' "$mk" && echo 1)" "$rel: check prints the gates run tally"
  assert_eq 1 "$(grep -qF -- '-z "$$CI"' "$mk" && echo 1)" "$rel: BEARING_ALLOW_SKIP is ignored under CI"
  assert_eq 1 "$(recipe "$mk" check | grep -q 'exit 1' && echo 1)" "$rel: check exits 1 on a recorded skip"
  t_end
done

t_begin "counts"
assert_eq 1 "$([ "$makefiles" -ge 2 ] && echo 1)" "the kit and at least one stack Makefile ($makefiles)"
assert_eq 1 "$([ "$gates" -ge 10 ] && echo 1)" "at least ten gates audited ($gates)"
t_end

echo "gate_selfaudit: $makefiles makefiles, $gates gates audited"
t_summary
