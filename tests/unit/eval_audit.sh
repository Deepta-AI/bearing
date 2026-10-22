#!/usr/bin/env bash
# tests/unit/eval_audit.sh: bin/eval-audit.py reads every graded, unblinded
# skill-evals run and sorts each expectation: discriminating (passes more with
# the skill), no signal (passes in every run of every arm), never passes,
# favours no skill, and flagged by a grader's eval_feedback. A synthetic
# workspace stands in for real runs.
set -u
. "$(dirname "$0")/../lib/assert.sh"

ws="$(tmpdir)"
# grade <iteration> <arm> <case dir> <pass,pass,...> [flagged text]
grade() {
  d="$ws/learn/iteration-$1/$3/$2/run-1"; mkdir -p "$d"
  python3 - "$d/grading.json" "$4" "${5:-}" <<'PY'
import json, sys
texts = ["Lists every learning", "Says the file is local", "Names the gh command", "Mentions the year"]
passed = [x == "1" for x in sys.argv[2].split(",")]
fb = {"suggestions": [{"assertion": sys.argv[3], "reason": "not discriminating"}]} if sys.argv[3] else None
d = {"expectations": [{"text": t, "passed": p, "evidence": "e"} for t, p in zip(texts, passed)],
     "summary": {"passed": sum(passed), "failed": len(passed) - sum(passed), "total": len(passed), "pass_rate": sum(passed) / len(passed)}}
if fb: d["eval_feedback"] = fb
json.dump(d, open(sys.argv[1], "w"))
PY
}
# expectation 1 discriminates, 2 always passes, 3 never passes, 4 favours no skill
for it in 1 2; do
  grade "$it" with_skill eval-1-list "1,1,0,0"
  grade "$it" without_skill eval-1-list "0,1,0,1" "Says the file is local"
done
# a blinded run (not yet unblinded) is not counted
mkdir -p "$ws/learn/iteration-3/eval-1-list/arm-1/run-1"
echo '{"expectations": [{"text": "Lists every learning", "passed": false}]}' > "$ws/learn/iteration-3/eval-1-list/arm-1/run-1/grading.json"
audit() { python3 "$KIT/bin/eval-audit.py" --ws "$ws" "$@"; }

t_begin "an empty workspace has nothing to audit and fails"
assert_exit 1 python3 "$KIT/bin/eval-audit.py" --ws "$(tmpdir)"
assert_contains "$T_OUT" "0 graded runs"
t_end

t_begin "every expectation is sorted and counted"
assert_exit 0 audit
assert_contains "$T_OUT" "eval-audit: 1 skills, 4 graded runs, 4 expectations: 1 discriminating, 1 no signal, 1 never passes, 1 favours no skill, 1 flagged"
assert_contains "$T_OUT" "no signal: learn case 1: Says the file is local (with 2/2, without 2/2)"
assert_contains "$T_OUT" "never passes: learn case 1: Names the gh command (with 0/2, without 0/2)"
assert_contains "$T_OUT" "favours no skill: learn case 1: Mentions the year (with 0/2, without 2/2)"
assert_contains "$T_OUT" "flagged: learn case 1: Says the file is local (not discriminating)"
assert_not_contains "$T_OUT" "Lists every learning (with"
t_end

t_begin "--skill limits it, and an unknown skill has no runs"
assert_exit 0 audit --skill learn
assert_exit 1 audit --skill adr
assert_contains "$T_OUT" "0 graded runs"
t_end

t_begin "--json writes the per-expectation counts"
assert_exit 0 audit --json "$ws/audit.json"
assert_eq "2" "$(python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));print([e for e in d["learn"]["1"] if e["text"]=="Lists every learning"][0]["with_skill"][1])' "$ws/audit.json")" "runs counted"
t_end

t_summary
