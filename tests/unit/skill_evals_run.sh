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
# Listed backwards, as a filesystem may (macOS did): the driver must not care.
json.dump({"run_summary": {k: {"pass_rate": {"mean": sum(v) / len(v)}} for k, v in sorted(rates.items(), reverse=True)}},
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
if os.environ.get("STUB_CONC"):
    import time
    with open(os.environ["STUB_CONC"], "a") as f:
        f.write(f"start {time.time()}\n")
    time.sleep(0.4)
    with open(os.environ["STUB_CONC"], "a") as f:
        f.write(f"end {time.time()}\n")
p = a[a.index("-p") + 1]
if os.environ.get("STUB_LIMIT") and "one run of a skill evaluation" in p:
    print(json.dumps({"type": "result", "is_error": True, "result": "You've hit your session limit \u00b7 resets 1am"})); sys.exit(1)
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
# --list reads only the board and git, so it keeps the caller's HOME (git's
# safe.directory lives there when the repository has another owner, as in the
# bash32 image).
list() { python3 "$KIT/bin/skill-evals-run.py" --board "$board" --list "$@"; }
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

t_begin "an executor may write its run folder and nothing else outside the repository"
python3 - "$d/calls.log" > "$d/adddir.txt" <<'PY2'
import json, sys
ex = [json.loads(l) for l in open(sys.argv[1]) if "one run of a skill evaluation" in l]
ok = 0
for a in ex:
    adds = [a[i + 1] for i, x in enumerate(a) if x == "--add-dir"]
    w = json.loads(a[a.index("--settings") + 1])["sandbox"]["filesystem"].get("allowWrite", [])
    ok += len(adds) == 1 and adds == w and adds[0].endswith("/run-1")
print(f"{ok} of {len(ex)}")
PY2
assert_eq "4 of 4" "$(cat "$d/adddir.txt")" "executors given only their run folder"
assert_eq "4" "$(find "$d/ws/learn/iteration-1" -name session.json | wc -l | tr -d ' ')" "session results kept"
t_end

t_begin "a relative workspace path works (measure hands it to a tool in another directory)"
rel="$(tmpdir)"; mkdir -p "$rel/here"
T_IN=""; t_run bash -c "cd '$rel/here' && HOME='$home' STUB_LOG='$d/calls.log' BRG_CLAUDE='$d/claude' BRG_SKILL_EVALS_WS=ws BRG_SKILL_EVALS_PRIVATE=private.json python3 '$KIT/bin/skill-evals-run.py' --board '$board' --out out --only learn"
assert_eq 0 "$T_RC" "exit"
assert_contains "$T_OUT" "1 skills chosen, 1 measured, 0 failed"
assert_file "$rel/here/ws/learn/iteration-1/benchmark.json"
t_end

t_begin "the next run of the same skill takes the next free iteration"
assert_exit 0 run --only learn
assert_file "$d/ws/learn/iteration-2/benchmark.json"
t_end

t_begin "skills are measured in parallel, never with more sessions open than -j"
: > "$d/conc.log"
STUB_CONC="$d/conc.log" assert_exit 0 run --only learn,test-cases -j 2 --parallel-skills 2
assert_contains "$T_OUT" "2 skills chosen, 2 measured, 0 failed"
peak="$(python3 - "$d/conc.log" <<'PY2'
import sys
ev = sorted((float(t), 1 if k == "start" else -1) for k, t in (l.split() for l in open(sys.argv[1])))
n = m = 0
for _, x in ev:
    n += x; m = max(m, n)
print(m)
PY2
)"
assert_eq 2 "$peak" "most sessions open at once"
assert_contains "$(cat "$d/private.json")" '"test-cases"'
assert_contains "$(cat "$d/private.json")" '"learn"'
t_end

t_begin "the usage limit stops the run: skills are limited, not failed, and no further session starts"
: > "$d/calls.log"
STUB_LIMIT=1 assert_exit 3 run --only learn,test-cases --parallel-skills 1 -j 1
assert_contains "$T_OUT" "stopped at the usage limit"
assert_contains "$T_OUT" "0 measured, 0 failed"
assert_eq "1" "$(wc -l < "$d/calls.log" | tr -d ' ')" "sessions started (only the one refused)"
assert_eq "True True" "$(python3 -c 'import json,sys;d=json.load(open(sys.argv[1]))["skills"];print(d["learn"].get("limited"), d["test-cases"].get("limited"))' "$d/out/summary.json")" "both limited"
t_end

t_begin "a skill whose executors fail is recorded with its error and fails the run"
STUB_FAIL=1 assert_exit 1 run --only learn
assert_contains "$T_OUT" "1 skills chosen, 0 measured, 1 failed"
assert_contains "$(cat "$d/out/summary.json")" "\"error\""
t_end

# A rival skill installed under the run's HOME, for the third arm.
mkdir -p "$home/.claude/skills/rival"
printf -- '---\nname: rival\ndescription: a rival\n---\n# rival\n' > "$home/.claude/skills/rival/SKILL.md"
ev() { HOME="$home" BRG_SKILL_EVALS_WS="$d/ws" BRG_SKILL_EVALS_PRIVATE="$d/private.json" python3 "$KIT/bin/skill-evals.py" "$@"; }

t_begin "alternative pairs a Bearing skill with an installed rival, privately"
assert_exit 0 ev alternative learn rival-pack:rival
assert_contains "$T_OUT" "learn: measured against rival-pack:rival"
assert_contains "$(cat "$d/private.json")" '"invoke": "rival-pack:rival"'
assert_exit 0 ev status
assert_contains "$T_OUT" "learn: paired with rival-pack:rival"
t_end

t_begin "alternative refuses a Bearing skill, a rival that is not installed, and an unknown skill"
assert_exit 1 ev alternative learn bearing:adr
assert_contains "$T_OUT" "is a Bearing skill"
assert_exit 1 ev alternative learn other:not-installed
assert_contains "$T_OUT" "not installed"
assert_exit 1 ev alternative no-such-skill rival-pack:rival
assert_contains "$T_OUT" "0 pairings written"
t_end

t_begin "a paired skill is measured in three arms"
: > "$d/calls.log"
assert_exit 0 run --only learn
assert_contains "$T_OUT" "with_the_alternative 0.50"
assert_eq "8" "$(wc -l < "$d/calls.log" | tr -d ' ')" "sessions (2 cases x 3 arms + 2 graders)"
assert_exit 0 ev alternative learn --clear
assert_contains "$T_OUT" "alternative cleared"
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
assert_exit 0 list --max 4
# A shallow clone (CI) lacks the parent commit: then git cannot say what
# changed, the driver says "history unreadable", and the skill still goes first.
if git -C "$KIT" cat-file -e "${learn_change}^" 2>/dev/null; then why="learn (changed since"; else why="learn (history unreadable from"; fi
assert_contains "$(printf '%s' "$T_OUT" | sed -n 1p)" "$why"
assert_contains "$(printf '%s' "$T_OUT" | sed -n 2p)" "ab-experiment (never measured)"
assert_contains "$(printf '%s' "$T_OUT" | sed -n 3p)" "accessibility (never measured)"
assert_contains "$(printf '%s' "$T_OUT" | sed -n 4p)" "adr (last measured 2026-09-01)"
assert_contains "$T_OUT" "4 skills chosen"
t_end

t_begin "a commit git cannot read puts the skill first and says why"
python3 - "$board" <<'PY2'
import json, sys
row = json.loads(open(sys.argv[1]).readline())
row["skill_evals"]["skills"]["learn"]["commit"] = "0000000000000000000000000000000000000000"
open(sys.argv[1], "w").write(json.dumps(row) + "\n")
PY2
assert_exit 0 list --max 1
assert_contains "$T_OUT" "learn (history unreadable from 0000000)"
t_end

t_begin "--max 0 chooses nothing and fails"
assert_exit 1 list --max 0
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
