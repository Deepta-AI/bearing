#!/usr/bin/env bash
# tests/unit/trigger_eval.sh: bin/trigger-eval.py grades what Claude loaded,
# and bin/lint-triggers.py holds evals/triggers.json to every skill. A stub
# claude loads the skill named after "LOAD:" in the request (none otherwise)
# and "FAIL" makes the session error. The real sessions run under
# make trigger-eval, not here.
set -u
. "$(dirname "$0")/../lib/assert.sh"

stub="$(tmpdir)"; out="$(tmpdir)"; cases="$(tmpdir)"
cat > "$stub/claude" <<'S'
#!/usr/bin/env bash
p="$2"
echo '{"type":"system","subtype":"init","session_id":"s0"}'
case "$p" in
  *FAIL*) echo '{"type":"result","is_error":true,"result":"Failed to authenticate"}'; exit 1 ;;
  *LOAD:*) s="${p#*LOAD:}"; s="${s%% *}"
    echo "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Skill\",\"input\":{\"skill\":\"bearing:$s\"}}]}}" ;;
esac
echo '{"type":"result","is_error":false,"result":"done"}'
S
chmod 755 "$stub/claude"
ev() { BRG_CLAUDE="$stub/claude" BRG_TRIGGER_EVAL_OUT="$out" BRG_TRIGGER_CASES="$cases/t.json" python3 "$KIT/bin/trigger-eval.py" -j 2 "$@"; }

t_begin "a loaded skill passes, a missed or wrong one fails, a near miss that loads it is a false trigger"
cat > "$cases/t.json" <<'J'
[{"skill": "adr", "should": ["record it LOAD:adr", "write it down LOAD:adr", "note the call"],
  "near": [{"prompt": "pick one LOAD:tech-decision", "expect": "tech-decision"}, {"prompt": "oops LOAD:adr", "expect": null}]}]
J
assert_exit 1 ev
assert_contains "$T_OUT" "adr: loaded on 2/3, false triggers 1/2; instead: none"
assert_contains "$T_OUT" "trigger-eval: 5 cases over 1 skills, 0 errored; recall 67% (2/3), false triggers 50% (1/2), near misses routed to the expected sibling 1/1"
t_end

t_begin "all loaded and no false trigger exits 0"
assert_exit 0 ev --kind should --min-recall 0.6
assert_contains "$T_OUT" "recall 67% (2/3)"
t_end

t_begin "a session that errors fails the run and names the error"
printf '[{"skill": "adr", "should": ["FAIL a", "FAIL b", "FAIL c"], "near": []}]\n' > "$cases/t.json"
assert_exit 1 ev
assert_contains "$T_OUT" "3 errored"
assert_contains "$T_OUT" "Failed to authenticate"
t_end

t_begin "a claude that prints nothing is an error, not a miss"
printf '[{"skill": "adr", "should": ["a", "b", "c"], "near": []}]\n' > "$cases/t.json"
assert_exit 1 env BRG_CLAUDE=true BRG_TRIGGER_EVAL_OUT="$out" BRG_TRIGGER_CASES="$cases/t.json" python3 "$KIT/bin/trigger-eval.py"
assert_contains "$T_OUT" "3 errored"
assert_contains "$T_OUT" "printed nothing"
t_end

t_begin "no case selected checks nothing and fails"
assert_exit 1 ev --only nope
assert_contains "$T_OUT" "0 cases selected"
t_end

t_begin "lint-triggers checks every skill and counts what it checked"
assert_exit 0 python3 "$KIT/bin/lint-triggers.py"
assert_contains "$T_OUT" "0 problems"
t_end

t_summary
