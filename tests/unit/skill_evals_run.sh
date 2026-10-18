#!/usr/bin/env bash
# tests/unit/skill_evals_run.sh: bin/skill-evals-run.py chooses a rotating set
# of skills from evals/scoreboard.jsonl and drives bin/skill-evals.py through
# executor and grader sessions; bin/eval-scoreboard.py --skill-evals writes the
# measurements into the row. A stub claude stands in for every session and a
# stub skill-creator for the benchmark; the real sessions run under
# make evals-weekly, not here.
set -u
. "$(dirname "$0")/../lib/assert.sh"

d="$(tmpdir)"
home="$d/home"
sc="$home/.claude/skills/skill-creator"
mkdir -p "$sc/agents" "$sc/scripts"
echo "# grader (stub)" > "$sc/agents/grader.md"
cat > "$sc/scripts/aggregate_benchmark.py" <<'PY'
import json, pathlib, sys
it = pathlib.Path(sys.argv[1])
rates = {}
for g in it.glob("eval-*/*/run-1/grading.json"):
    rates.setdefault(g.parent.parent.name, []).append(json.load(open(g))["summary"]["pass_rate"])
json.dump({"run_summary": {k: {"pass_rate": {"mean": sum(v) / len(v)}} for k, v in rates.items()}},
          open(it / "benchmark.json", "w"))
PY

# The stub claude: an executor writes its transcript, a grader passes the
# with_skill arm at $STUB_SKILL_RATE (default 1.0) and the rest at 0.5. Every
# call's arguments are logged.
cat > "$d/claude" <<'S'
#!/usr/bin/env python3
import json, os, re, sys
a = sys.argv[1:]
with open(os.environ["STUB_LOG"], "a") as f:
    f.write(json.dumps(a) + "\n")
p = a[a.index("-p") + 1]
if os.environ.get("STUB_FAIL") and "one run of a skill evaluation" in p:
    print(json.dumps({"type": "result", "is_error": True, "result": "stub failure"})); sys.exit(1)
if "one run of a skill evaluation" in p:
    rd = re.search(r"write (\S+)/transcript\.md", p).group(1)
    open(os.path.join(rd, "transcript.md"), "w").write("stub run\n")
elif "You grade one case" in p:
    for run in re.findall(r"^- arm-\d+: (\S+)$", p, re.M):
        arm = open(os.path.join(run, "prompt.txt")).read()
        rate = float(os.environ.get("STUB_SKILL_RATE", "1.0")) if "SKILL.md and follow it" in arm else 0.5
        json.dump({"expectations": [], "summary": {"passed": 1, "failed": 0, "total": 1, "pass_rate": rate}},
                  open(os.path.join(run, "grading.json"), "w"))
print(json.dumps({"type": "result", "is_error": False, "result": "done", "duration_ms": 1500,
                  "usage": {"input_tokens": 100, "output_tokens": 20}, "modelUsage": {"stub-model": {}}}))
S
chmod 755 "$d/claude"

board="$d/scoreboard.jsonl"
run() {
  HOME="$home" STUB_LOG="$d/calls.log" BRG_CLAUDE="$d/claude" \
    BRG_SKILL_EVALS_WS="$d/ws" BRG_SKILL_EVALS_PRIVATE="$d/private.json" \
    python3 "$KIT/bin/skill-evals-run.py" --board "$board" --out "$d/out" "$@"
}

t_begin "an unknown skill chooses nothing and fails"
assert_exit 1 run --only no-such-skill
assert_contains "$T_OUT" "0 skills chosen"
t_end

t_begin "one skill is prepared, run, graded, unblinded and measured"
: > "$d/calls.log"
assert_exit 0 run --only learn
assert_contains "$T_OUT" "skill-evals-run: 1 skills chosen, 1 measured, 0 failed"
assert_contains "$T_OUT" "learn: with_skill 1.00, without_skill 0.50"
assert_file "$d/out/summary.json"
assert_eq "1.0" "$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["skills"]["learn"]["arms"]["with_skill"]["pass_rate"])' "$d/out/summary.json")" "with_skill rate"
assert_eq "6" "$(wc -l < "$d/calls.log" | tr -d ' ')" "sessions (2 cases x 2 arms + 2 graders)"
t_end

t_begin "every session runs in the sandbox with no settings and no Skill tool"
python3 - "$d/calls.log" > "$d/flags.txt" <<'PY'
import json, sys
bad = 0
for line in open(sys.argv[1]):
    a = json.loads(line)
    s = json.loads(a[a.index("--settings") + 1])
    ok = (s["sandbox"]["enabled"] and s["sandbox"]["failIfUnavailable"]
          and not s["sandbox"]["allowUnsandboxedCommands"]
          and set(s["sandbox"]["network"]["allowedDomains"]) <= {"localhost", "127.0.0.1"}
          and "~/.ssh" in s["sandbox"]["filesystem"]["denyRead"]
          and a[a.index("--setting-sources") + 1] == ""
          and "Skill" in a[a.index("--disallowedTools") + 1])
    bad += not ok
print(f"bad {bad}")
PY
assert_eq "bad 0" "$(cat "$d/flags.txt")" "sessions outside the sandbox"
t_end

t_begin "the next run of the same skill takes the next free iteration"
assert_exit 0 run --only learn
assert_file "$d/ws/learn/iteration-2/benchmark.json"
t_end

t_begin "a skill whose executors fail is recorded with its error and fails the run"
STUB_FAIL=1 assert_exit 1 run --only learn
assert_contains "$T_OUT" "1 skills chosen, 0 measured, 1 failed"
assert_contains "$(cat "$d/out/summary.json")" "\"error\""
t_end

# Rotation: a board where every skill but two was measured at HEAD, one of the
# measured skills last measured just before its folder changed.
head="$(git -C "$KIT" rev-parse HEAD)"
learn_change="$(git -C "$KIT" log -1 --format=%H -- plugins/bearing/skills/learn)"
python3 - "$KIT" "$board" "$head" "$learn_change" <<'PY'
import json, os, sys
kit, board, head, change = sys.argv[1:]
skills = sorted(n for n in os.listdir(os.path.join(kit, "evals")) if os.path.isfile(os.path.join(kit, "evals", n, "evals.json")))
measured = {s: {"commit": head, "date": "2026-10-10", "arms": {"with_skill": {"pass_rate": 1.0}}} for s in skills[2:]}
measured["adr"] = {"commit": head, "date": "2026-09-01", "arms": {"with_skill": {"pass_rate": 1.0}}}
measured["learn"] = {"commit": change + "^", "date": "2026-10-12", "arms": {"with_skill": {"pass_rate": 1.0}}}
row = {"date": "2026-10-12", "skill_evals": {"skills": measured}}
open(board, "w").write(json.dumps(row) + "\n")
PY

t_begin "rotation: changed since measured first, then never measured, then the oldest"
assert_exit 0 run --list --max 4
assert_contains "$(printf '%s' "$T_OUT" | sed -n 1p)" "learn (changed since"
assert_contains "$(printf '%s' "$T_OUT" | sed -n 2p)" "ab-experiment (never measured)"
assert_contains "$(printf '%s' "$T_OUT" | sed -n 3p)" "accessibility (never measured)"
assert_contains "$(printf '%s' "$T_OUT" | sed -n 4p)" "adr (last measured 2026-09-01)"
assert_contains "$T_OUT" "4 skills chosen"
t_end

t_begin "--max 0 chooses nothing and fails"
assert_exit 1 run --list --max 0
assert_contains "$T_OUT" "0 skills chosen"
t_end

# The scoreboard: a summary goes into the row; a drop since that skill's last
# measurement is a regression.
trig="$d/t.json"; harn="$d/h.json"
python3 - "$trig" "$harn" <<'PY'
import json, sys
json.dump({"results": [{"skill": "adr", "kind": "should", "status": "pass"}, {"skill": "adr", "kind": "near", "status": "pass"}]}, open(sys.argv[1], "w"))
json.dump([{"scenario": "push", "status": "pass"}], open(sys.argv[2], "w"))
PY
# shellcheck disable=SC2120  # called with arguments through assert_exit
sb() { python3 "$KIT/bin/eval-scoreboard.py" --board "$d/sb.jsonl" --trigger "$trig" --harness "$harn" "$@"; }

t_begin "a skill-evals summary fills the row's skill_evals slot"
run --only learn >/dev/null 2>&1
assert_exit 0 sb --skill-evals "$d/out/summary.json"
assert_contains "$T_OUT" "1 skills measured"
assert_eq "1.0" "$(python3 -c 'import json,sys;print(json.loads(open(sys.argv[1]).readlines()[-1])["skill_evals"]["skills"]["learn"]["arms"]["with_skill"]["pass_rate"])' "$d/sb.jsonl")" "row rate"
t_end

t_begin "with_skill down more than the allowed drop since its last measurement fails"
STUB_SKILL_RATE=0.7 run --only learn >/dev/null 2>&1
sb >/dev/null 2>&1   # a row with no skill-evals in between
assert_exit 1 sb --skill-evals "$d/out/summary.json"
assert_contains "$T_OUT" "regression: skill learn with_skill 100% -> 70%"
t_end

t_begin "a missing summary file fails and writes nothing"
before="$(wc -l < "$d/sb.jsonl" | tr -d ' ')"
assert_exit 2 sb --skill-evals "$d/nope.json"
assert_eq "$before" "$(wc -l < "$d/sb.jsonl" | tr -d ' ')" "rows"
t_end

t_summary
