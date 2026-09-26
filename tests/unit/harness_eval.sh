#!/usr/bin/env bash
# tests/unit/harness_eval.sh: bin/harness-eval.py fails closed. With a claude
# that starts a session and does nothing, every scenario is "not exercised"
# and the run exits 1 with the counts; an unknown scenario exits 2; --list
# names all eight. The real sessions run under make harness-eval, not here.
set -u
. "$(dirname "$0")/../lib/assert.sh"

stub="$(tmpdir)"; projects="$(tmpdir)"; out="$(tmpdir)"
printf '#!/usr/bin/env bash\necho %s\n' "'{\"type\":\"system\",\"subtype\":\"init\",\"session_id\":\"s0\"}'" > "$stub/claude"
chmod 755 "$stub/claude"
ev() { BRG_CLAUDE="$stub/claude" BRG_CLAUDE_PROJECTS="$projects" BRG_HARNESS_EVAL_OUT="$out" python3 "$KIT/bin/harness-eval.py" "$@"; }

t_begin "lists the six scenarios"
assert_exit 0 ev --list
assert_eq 8 "$(printf '%s\n' "$T_OUT" | grep -c .)" "scenario count"
t_end

t_begin "an unknown scenario is refused"
assert_exit 2 ev --only nope
assert_contains "$T_OUT" "unknown scenario(s): nope"
t_end

t_begin "a session that reaches no gate fails, with the counts"
assert_exit 1 ev --only push,deploy,edit-lint,stop-green,stop-red
assert_contains "$T_OUT" "push: not exercised"
assert_contains "$T_OUT" "stop-red: not exercised"
assert_contains "$T_OUT" "harness-eval: 5 scenarios, 5 runs, 0 passed, 0 failed, 5 not exercised"
assert_eq 1 "$(find "$out" -name results.json | wc -l | tr -d ' ')" "results written"
t_end

t_begin "compaction with no session is a failure, not a pass"
assert_exit 1 ev --only compaction
assert_contains "$T_OUT" "harness-eval: 1 scenarios, 1 runs, 0 passed"
t_end

t_begin "repeat runs each scenario on fresh fixtures and reports its rate"
assert_exit 1 ev --only push,edit-lint --repeat 2
assert_contains "$T_OUT" "push 1/2: not exercised"
assert_contains "$T_OUT" "push 2/2: not exercised"
assert_contains "$T_OUT" "pass rate per scenario: push 0/2, edit-lint 0/2"
assert_contains "$T_OUT" "2 scenarios, 4 runs, 0 passed"
assert_contains "$T_OUT" "below the 100% rate: push, edit-lint"
assert_exit 2 ev --only push --repeat 0
t_end

t_summary
