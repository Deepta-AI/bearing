#!/usr/bin/env bash
# tests/unit/gate_probe.sh: plugins/bearing/skills/gate-audit/scripts/probe_gates.py
# runs each gate of a fixture repository in an emptied throwaway copy and
# reports: a gate that fails on empty input and prints a count is clean; a
# gate that passes on empty input, one that prints no count, and a hook
# that exits 0 with nothing staged are problems; a gate that needs the
# network and one that times out are "not probed"; a CI make call is
# merged with the check prerequisite of the same name. The fixture itself
# is never written. Zero gates, or zero gates probed, fails.
set -u
. "$(dirname "$0")/../lib/assert.sh"
CHK="$KIT/plugins/bearing/skills/gate-audit/scripts/probe_gates.py"
TAB="$(printf '\t')"

# fixture <dir> <check prerequisites>: a Makefile with five gates, a script, a CI file, a hook.
fixture() {
  mkdir -p "$1/src" "$1/scripts" "$1/.githooks"
  printf 'a\n' > "$1/src/a.txt"
  cat > "$1/scripts/count.sh" <<'SH'
#!/usr/bin/env bash
n="$(ls src 2>/dev/null | wc -l | tr -d ' ')"
[ "$n" -gt 0 ] || { echo "good: 0 files, nothing checked"; exit 1; }
echo "good: $n files checked"
SH
  {
    printf 'check: %s\n\n' "$2"
    printf 'good:\n%s@bash scripts/count.sh\n\n' "$TAB"
    printf 'bad:\n%s@ls src >/dev/null 2>&1; echo "bad: ok"\n\n' "$TAB"
    printf 'nocount:\n%s@test -n "$$(ls src 2>/dev/null)"\n\n' "$TAB"
    printf 'net:\n%s@curl -s https://example.invalid >/dev/null; echo "net: 1 checked"\n\n' "$TAB"
    printf 'slow:\n%s@sleep 5\n' "$TAB"
  } > "$1/Makefile"
  printf 'lint:\n  script:\n    - make good\n' > "$1/.gitlab-ci.yml"
  printf '#!/bin/sh\nexit 0\n' > "$1/.githooks/pre-commit"; chmod +x "$1/.githooks/pre-commit"
}

t_begin "each gate is probed on an emptied copy and classified"
d="$(tmpdir)/repo"; fixture "$d" "good bad nocount net slow"
assert_exit 1 python3 "$CHK" --repo "$d" --timeout 2
assert_contains "$T_OUT" "gate: good (make check; CI .gitlab-ci.yml job lint): empty input fails (exit 2), count printed: 'good: 0 files, nothing checked'; kept Makefile, scripts/count.sh"
assert_contains "$T_OUT" "problem: bad: passes on empty input"
assert_contains "$T_OUT" "problem: bad: prints no count"
assert_contains "$T_OUT" "problem: nocount: prints no count"
assert_not_contains "$T_OUT" "problem: nocount: passes" "nocount fails on empty input"
assert_contains "$T_OUT" "not probed: net (make check): needs network or a service (curl)"
assert_contains "$T_OUT" "not probed: slow (make check): timed out after 2s on empty input"
assert_contains "$T_OUT" "problem: .githooks/pre-commit: passes on empty input"
assert_contains "$T_OUT" "gate-probe: 6 gates found (make 5, CI 1 in 1 files, hooks 1), 4 probed, 2 fail on empty input, 1 print a count, 2 not probed, 3 need work"
t_end

t_begin "the repository itself is not written"
assert_file "$d/src/a.txt"
assert_eq "" "$(ls -a "$d" | grep -x '.git')" "no .git created in the fixture"
t_end

t_begin "only real gates: a clean set passes"
d="$(tmpdir)/clean"; fixture "$d" "good"; rm "$d/.githooks/pre-commit"
assert_exit 0 python3 "$CHK" --repo "$d"
assert_contains "$T_OUT" "1 probed, 1 fail on empty input, 1 print a count, 0 not probed, 0 need work"
t_end

t_begin "CI: install lines are not targets, a target the Makefile lacks is not probed, git-listing gates see an empty repository"
d="$(tmpdir)/ci"; fixture "$d" "gitls"; rm "$d/.githooks/pre-commit"
printf 'gitls:\n%s@n=$$(git ls-files -co --exclude-standard | wc -l | tr -d " "); [ "$$n" -gt 0 ] || { echo "gitls: 0 files, nothing checked"; exit 1; }; echo "gitls: $$n files"\n' "$TAB" >> "$d/Makefile"
printf 'build:\n  script:\n    - apt-get install -y make git\n    - cd /tmp/x && make setup\n' > "$d/.gitlab-ci.yml"
assert_exit 0 python3 "$CHK" --repo "$d"
assert_contains "$T_OUT" "gate: gitls (make check): empty input fails (exit 2), count printed: 'gitls: 0 files, nothing checked'"
assert_contains "$T_OUT" "not probed: setup (CI .gitlab-ci.yml job build): no target setup in the root Makefile"
assert_not_contains "$T_OUT" "gate: git " "an apt-get argument is not a make target"
t_end

t_begin "--only limits the audit"
d="$(tmpdir)/only"; fixture "$d" "good bad"
assert_exit 0 python3 "$CHK" --repo "$d" --only good
assert_not_contains "$T_OUT" "bad"
t_end

t_begin "empty input fails: zero gates found, or zero probed"
d="$(tmpdir)/empty"; mkdir -p "$d"
assert_exit 1 python3 "$CHK" --repo "$d"
assert_contains "$T_OUT" "0 gates found"
fixture "$d" "net"; rm "$d/.githooks/pre-commit" "$d/.gitlab-ci.yml"
assert_exit 1 python3 "$CHK" --repo "$d"
assert_contains "$T_OUT" "0 gates probed, nothing checked"
t_end

t_summary
