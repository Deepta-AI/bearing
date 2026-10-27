#!/usr/bin/env bash
# tests/unit/eval_scoreboard.sh: bin/eval-scoreboard.py turns one trigger-eval
# and one harness-eval results.json into a row of evals/scoreboard.jsonl and
# fails on zero cases or a regression; bin/evals-weekly.sh runs both suites
# and the scoreboard. The suites are stubbed through BRG_TRIGGER_EVAL and
# BRG_HARNESS_EVAL; the real sessions run under make evals-weekly, not here.
set -u
. "$(dirname "$0")/../lib/assert.sh"

d="$(tmpdir)"
board="$d/scoreboard.jsonl"

# trigger <file> <should pass> <should fail> <near fail> <near pass> [skill]
trigger() {
  python3 - "$@" <<'PY'
import json, sys
path, sp, sf, nf, np = sys.argv[1], *map(int, sys.argv[2:6])
skill = sys.argv[6] if len(sys.argv) > 6 else "adr"
r = []
r += [{"skill": skill, "kind": "should", "status": "pass", "first": skill, "expect": skill}] * sp
r += [{"skill": skill, "kind": "should", "status": "fail", "first": None, "expect": skill}] * sf
r += [{"skill": skill, "kind": "near", "status": "fail", "first": skill, "expect": None}] * nf
r += [{"skill": skill, "kind": "near", "status": "pass", "first": None, "expect": None}] * np
json.dump({"sources": "project,local", "model": None, "results": r}, open(path, "w"))
PY
}
# harness <file> <scenario:status>...
harness() {
  f="$1"; shift
  python3 - "$f" "$@" <<'PY'
import json, sys
rows = [{"scenario": a.split(":")[0], "repeat": 1, "status": a.split(":")[1]} for a in sys.argv[2:]]
json.dump(rows, open(sys.argv[1], "w"))
PY
}
sb() { python3 "$KIT/bin/eval-scoreboard.py" --board "$board" "$@"; }
rows() { if [ -f "$board" ]; then wc -l < "$board" | tr -d ' '; else echo 0; fi; }

t_begin "zero cases checked fails and writes nothing"
trigger "$d/t0.json" 0 0 0 0
harness "$d/h0.json"
assert_exit 1 sb --trigger "$d/t0.json" --harness "$d/h0.json"
assert_contains "$T_OUT" "0 cases checked"
assert_eq 0 "$(rows)" "rows"
t_end

t_begin "a missing results file fails and writes nothing"
harness "$d/h1.json" push:pass
assert_exit 2 sb --trigger "$d/nope.json" --harness "$d/h1.json"
assert_contains "$T_OUT" "nope.json"
assert_eq 0 "$(rows)" "rows"
t_end

t_begin "the first row is written, counted and has an empty skill-evals slot"
trigger "$d/t1.json" 9 1 0 5
harness "$d/h1.json" push:pass deploy:pass
assert_exit 0 sb --trigger "$d/t1.json" --harness "$d/h1.json"
assert_contains "$T_OUT" "eval-scoreboard: 15 trigger cases, 2 harness runs checked"
assert_contains "$T_OUT" "recall 90%"
assert_contains "$T_OUT" "no previous row"
assert_eq 1 "$(rows)" "rows"
assert_eq "None" "$(python3 -c 'import json,sys;print(json.loads(open(sys.argv[1]).readline())["skill_evals"])' "$board")" "skill_evals"
t_end

t_begin "a steady run passes and prints the change since the last row"
assert_exit 0 sb --trigger "$d/t1.json" --harness "$d/h1.json"
assert_contains "$T_OUT" "recall 90% (+0.0 points)"
assert_eq 2 "$(rows)" "rows"
t_end

t_begin "recall down more than the allowed drop fails and still keeps the row"
trigger "$d/t2.json" 8 2 0 5
assert_exit 1 sb --trigger "$d/t2.json" --harness "$d/h1.json"
assert_contains "$T_OUT" "regression: recall 90% -> 80%"
assert_eq 3 "$(rows)" "rows"
t_end

t_begin "a wider allowed drop lets the same move pass"
trigger "$d/t3.json" 8 2 0 5
assert_exit 0 sb --trigger "$d/t3.json" --harness "$d/h1.json" --max-drop 0.15
t_end

t_begin "more false triggers than allowed fails"
trigger "$d/t4.json" 8 2 2 3
assert_exit 1 sb --trigger "$d/t4.json" --harness "$d/h1.json"
assert_contains "$T_OUT" "regression: false triggers 0% -> 40%"
t_end

t_begin "a harness scenario that passed and now fails is a regression"
trigger "$d/t5.json" 8 2 0 5
harness "$d/h5.json" push:pass "deploy:not exercised"
sb --trigger "$d/t5.json" --harness "$d/h1.json" >/dev/null 2>&1
assert_exit 1 sb --trigger "$d/t5.json" --harness "$d/h5.json"
assert_contains "$T_OUT" "regression: harness deploy 100% -> 0%"
t_end

t_begin "a per-skill move is listed and never fails the run"
trigger "$d/t6.json" 8 2 0 5 adr
sb --trigger "$d/t6.json" --harness "$d/h1.json" >/dev/null 2>&1
python3 - "$d/t6.json" "$d/t7.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
r = d["results"]
r[0]["status"] = "fail"
json.dump(d, open(sys.argv[2], "w"))
PY
assert_exit 0 sb --trigger "$d/t7.json" --harness "$d/h1.json" --max-drop 0.5
assert_contains "$T_OUT" "adr: loaded 8/10 -> 7/10"
t_end

t_begin "a run cut short by the usage limit writes an honest row and no false regression"
lb="$d/limited.jsonl"
trigger "$d/l1.json" 9 1 0 5
harness "$d/lh1.json" push:pass deploy:pass
python3 "$KIT/bin/eval-scoreboard.py" --board "$lb" --trigger "$d/l1.json" --harness "$d/lh1.json" >/dev/null 2>&1
python3 - "$d/lh2.json" <<'PY2'
import json, sys
json.dump([{"scenario": "push", "status": "not run"}, {"scenario": "deploy", "status": "not run"}], open(sys.argv[1], "w"))
PY2
assert_exit 0 python3 "$KIT/bin/eval-scoreboard.py" --board "$lb" --trigger "$d/l1.json" --harness "$d/lh2.json"
assert_contains "$T_OUT" "stopped at the usage limit: harness (2 scenarios not run)"
assert_contains "$T_OUT" "0 regressions"
assert_eq "0 2" "$(tail -1 "$lb" | python3 -c 'import json,sys;h=json.load(sys.stdin)["harness"];print(h["runs"], h["not_run"])')" "harness runs, not run"
t_end

t_begin "rows measuring different skills are compared only on the skills both measured"
rb="$d/rotation.jsonl"
trigger "$d/r1.json" 3 0 0 2 adr
python3 "$KIT/bin/eval-scoreboard.py" --board "$rb" --trigger "$d/r1.json" --harness "$d/h1.json" >/dev/null 2>&1
trigger "$d/r2.json" 0 3 0 2 learn
assert_exit 0 python3 "$KIT/bin/eval-scoreboard.py" --board "$rb" --trigger "$d/r2.json" --harness "$d/h1.json"
assert_contains "$T_OUT" "no skill measured before, nothing compared"
assert_not_contains "$T_OUT" "regression: recall"
trigger "$d/r3.json" 1 2 0 2 adr
assert_exit 1 python3 "$KIT/bin/eval-scoreboard.py" --board "$rb" --trigger "$d/r3.json" --harness "$d/h1.json"
assert_contains "$T_OUT" "regression: recall 100% -> 33% over 1 skills"
t_end

# evals-weekly: stub suites write their results where the runner points them.
# The runner measures the clone it sits in, so a copy runs in a clean one.
repo="$(tmpdir)"
mkdir -p "$repo/bin" "$repo/evals"
cp "$KIT/bin/evals-weekly.sh" "$KIT/bin/eval-scoreboard.py" "$repo/bin/"
git -C "$repo" init -q && git -C "$repo" add -A && git -C "$repo" -c user.email=t@t -c user.name=t commit -q -m init
stubs="$(tmpdir)"
cat > "$stubs/trigger" <<S
#!/usr/bin/env bash
mkdir -p "\$BRG_TRIGGER_EVAL_OUT/run" && cp "$d/t1.json" "\$BRG_TRIGGER_EVAL_OUT/run/results.json"
echo "trigger-eval: stub"; exit \${STUB_RC:-0}
S
cat > "$stubs/harness" <<S
#!/usr/bin/env bash
mkdir -p "\$BRG_HARNESS_EVAL_OUT/run" && cp "$d/h1.json" "\$BRG_HARNESS_EVAL_OUT/run/results.json"
echo "harness-eval: stub"
S
cat > "$stubs/skills" <<'S'
#!/usr/bin/env bash
while [ $# -gt 0 ]; do [ "$1" = --out ] && out="$2"; shift; done
mkdir -p "$out"
echo '{"skills": {"adr": {"commit": "c0", "date": "2026-10-19", "cases": 2, "arms": {"with_skill": {"pass_rate": 1.0}, "without_skill": {"pass_rate": 0.5}}, "margin": 0.5, "result": "bearing ahead"}}}' > "$out/summary.json"
echo "skill-evals-run: stub"
S
chmod 755 "$stubs/trigger" "$stubs/harness" "$stubs/skills"
wk() { BRG_SKILL_EVALS="$stubs/skills" BRG_TRIGGER_EVAL="$stubs/trigger" BRG_HARNESS_EVAL="$stubs/harness" BRG_SCOREBOARD="${BOARD_AT:-$d/weekly.jsonl}" bash "$repo/bin/evals-weekly.sh" "$@"; }

t_begin "the weekly run runs both suites and writes one row"
assert_exit 0 wk
assert_contains "$T_OUT" "trigger-eval: stub"
assert_contains "$T_OUT" "harness-eval: stub"
assert_contains "$T_OUT" "skill-evals-run: stub"
assert_contains "$T_OUT" "1 skills measured"
assert_contains "$T_OUT" "eval-scoreboard: 15 trigger cases, 2 harness runs checked"
assert_eq 1 "$(wc -l < "$d/weekly.jsonl" | tr -d ' ')" "weekly rows"
t_end

t_begin "a failing suite fails the weekly run after the row is written"
STUB_RC=1 assert_exit 1 wk
assert_eq 2 "$(wc -l < "$d/weekly.jsonl" | tr -d ' ')" "weekly rows"
t_end

t_begin "a dirty tree is refused before anything runs"
echo x > "$repo/untracked.txt"
assert_exit 2 wk
assert_contains "$T_OUT" "uncommitted changes"
assert_not_contains "$T_OUT" "trigger-eval: stub"
rm -f "$repo/untracked.txt"
t_end

t_begin "an uncommitted board row in the clone does not block the next run"
BOARD_AT="$repo/evals/scoreboard.jsonl" assert_exit 0 wk
BOARD_AT="$repo/evals/scoreboard.jsonl" assert_exit 0 wk
assert_eq 2 "$(wc -l < "$repo/evals/scoreboard.jsonl" | tr -d ' ')" "board rows in the clone"
t_end

t_begin "evals-timer prints both units for this clone and installs nothing"
bin="$(tmpdir)"; printf '#!/bin/sh\n' > "$bin/claude"; chmod 755 "$bin/claude"
assert_exit 0 env PATH="$bin:$PATH" HOME="$d/home" bash "$KIT/bin/evals-timer.sh"
assert_contains "$T_OUT" "ExecStart=/usr/bin/env bash $KIT/bin/evals-weekly.sh"
assert_contains "$T_OUT" "OnCalendar=Sun *-*-* 02:00"
assert_eq "no" "$([ -e "$d/home/.config/systemd" ] && echo yes || echo no)" "units written"
t_end

t_begin "evals-timer without the claude CLI on PATH fails and says so"
assert_exit 1 env PATH="$(minimal_path git dirname bash)" bash "$KIT/bin/evals-timer.sh"
assert_contains "$T_OUT" "claude is not on PATH"
t_end

t_summary
