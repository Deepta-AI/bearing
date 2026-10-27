#!/usr/bin/env bash
# tests/unit/trigger_rotation.sh: bin/trigger-rotation.py picks the skills
# trigger-eval runs this week: every skill whose folder changed since the row
# that last measured its triggers, plus a rotating quarter of all skills by ISO
# week, so each is covered at least monthly and the run stays inside the
# plan's limits (all 547 cases at once hit the session limit on 22 Oct 2026).
set -u
. "$(dirname "$0")/../lib/assert.sh"

d="$(tmpdir)"
board="$d/scoreboard.jsonl"
rot() { python3 "$KIT/bin/trigger-rotation.py" --board "$board" "$@"; }
n_skills="$(python3 -c 'import json,sys;print(len({c["skill"] for c in json.load(open(sys.argv[1]))}))' "$KIT/evals/triggers.json")"

t_begin "with no board, a quarter of the skills by week, the same week always the same quarter"
: > "$board"
assert_exit 0 rot --week 1
q1="$T_OUT"
assert_exit 0 rot --week 5
assert_eq "$q1" "$T_OUT" "week 1 and week 5 pick the same quarter"
assert_exit 0 rot --week 2
assert_not_contains ",$T_OUT," ",$(printf '%s' "$q1" | cut -d, -f1),"
t_end

t_begin "the four quarters together cover every skill once"
all="$(for w in 0 1 2 3; do rot --week "$w" | tr ',' '\n'; done | sort)"
assert_eq "$n_skills" "$(printf '%s\n' "$all" | grep -c .)" "skills covered"
assert_eq "$n_skills" "$(printf '%s\n' "$all" | sort -u | grep -c .)" "none twice"
t_end

t_begin "a skill changed since its last measured row joins the week, whatever its quarter"
head="$(git -C "$KIT" rev-parse HEAD)"
learn_change="$(git -C "$KIT" log -1 --format=%H -- plugins/bearing/skills/learn)"
python3 - "$KIT" "$board" "$head" "$learn_change" <<'PY'
import json, sys
kit, board, head, change = sys.argv[1:]
skills = sorted({c["skill"] for c in json.load(open(f"{kit}/evals/triggers.json"))})
row = {"date": "2026-10-20", "commit": head, "trigger": {"skills": {s: [3, 3, 0, 2] for s in skills if s != "learn"}}}
old = {"date": "2026-10-13", "commit": change + "^", "trigger": {"skills": {"learn": [3, 3, 0, 2]}}}
open(board, "w").write(json.dumps(old) + "\n" + json.dumps(row) + "\n")
PY
for w in 0 1 2 3; do
  rot --week "$w" | tr ',' '\n' | grep -qx learn || continue
  in_quarter="$w"
done
other=$(( (in_quarter + 1) % 4 ))
assert_exit 0 rot --week "$other" --list
assert_contains "$T_OUT" "learn ("
t_end

t_begin "--list says why each skill is in, and counts them"
assert_contains "$T_OUT" "(quarter $other of 4)"
assert_contains "$T_OUT" "trigger-rotation:"
t_end

t_begin "triggers.json with no skills chooses nothing and fails"
echo '[]' > "$d/empty.json"
assert_exit 1 python3 "$KIT/bin/trigger-rotation.py" --board "$board" --cases "$d/empty.json"
assert_contains "$T_OUT" "0 skills"
t_end

t_summary
