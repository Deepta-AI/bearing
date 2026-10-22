#!/usr/bin/env bash
# tests/unit/skill_tune.sh: bin/skill-tune.py picks the weakest measured skill,
# has a proposer session edit a copy of it, measures the copy against the
# skill as it is, and keeps the edit as a patch only when the copy scores
# higher by the margin. The proposer, the measurements and the lint are stubs;
# the real sessions run under `python3 bin/skill-tune.py`, not here.
set -u
. "$(dirname "$0")/../lib/assert.sh"

d="$(tmpdir)"
board="$d/scoreboard.jsonl"
python3 - "$board" <<'PY'
import json, sys
m = lambda w, wo: {"commit": "c0", "date": "2026-10-20", "arms": {"with_skill": {"pass_rate": w}, "without_skill": {"pass_rate": wo}}}
row = {"date": "2026-10-20", "skill_evals": {"skills": {"adr": m(0.9, 0.5), "learn": m(0.5, 0.4), "spike": m(0.8, 0.2)}}}
open(sys.argv[1], "w").write(json.dumps(row) + "\n")
PY

# Proposer stub: edits SKILL.md in its working directory and writes the
# rationale; STUB_PROPOSE=none makes no edit.
cat > "$d/claude" <<'S'
#!/usr/bin/env bash
echo "$*" >> "$STUB_LOG"
if [ "${STUB_PROPOSE:-edit}" = edit ]; then
  printf '\n- Check the result before reporting it.\n' >> SKILL.md
  r="$(printf '%s' "$*" | grep -o '[^ ]*/rationale\.md' | head -1)"
  echo "The failed cases skipped the final check." > "$r"
fi
echo '{"type":"result","is_error":false,"result":"done"}'
S
# Measurement stub: the copy under test scores $STUB_CAND, the skill as it is
# $STUB_BASE; it tells them apart by the kit it was started from.
cat > "$d/measure" <<'S'
#!/usr/bin/env bash
kit="$1"; shift
while [ $# -gt 0 ]; do case "$1" in --out) out="$2"; shift;; --only) skill="$2"; shift;; esac; shift; done
case "$kit" in *candidate*) r="${STUB_CAND:-0.9}";; *) r="${STUB_BASE:-0.5}";; esac
if [ -n "${STUB_WHEN:-}" ]; then
  echo "start $(python3 -c 'import time;print(time.time())')" >> "$STUB_WHEN"; sleep 0.5
  echo "end $(python3 -c 'import time;print(time.time())')" >> "$STUB_WHEN"
fi
mkdir -p "$out"
if [ -n "${STUB_HELD_BASE:-}" ]; then
  case "$kit" in *candidate*) h="$STUB_HELD_CAND";; *) h="$STUB_HELD_BASE";; esac
  g="$out/ws/$skill/iteration-1/eval-3-proposed-not-decided/with_skill/run-1"; mkdir -p "$g"
  printf '{"expectations": [], "summary": {"pass_rate": %s}}\n' "$h" > "$g/grading.json"
fi
printf '{"skills": {"%s": {"cases": 2, "arms": {"with_skill": {"pass_rate": %s}, "without_skill": {"pass_rate": 0.4}}}}}\n' "$skill" "$r" > "$out/summary.json"
echo "measured $skill in $kit: $r"
S
chmod 755 "$d/claude" "$d/measure"
fresh_out() { python3 -c 'import shutil,sys; shutil.rmtree(sys.argv[1], ignore_errors=True)' "$d/out"; }
tune() {
  STUB_LOG="$d/calls.log" BRG_CLAUDE="$d/claude" BRG_SKILL_TUNE_MEASURE="$d/measure" \
    BRG_SKILL_TUNE_LINT="true" python3 "$KIT/bin/skill-tune.py" --board "$board" --out "$d/out" "$@"
}

t_begin "an empty board has nothing to tune and fails"
: > "$d/empty.jsonl"
assert_exit 1 python3 "$KIT/bin/skill-tune.py" --board "$d/empty.jsonl" --list
assert_contains "$T_OUT" "0 measured skills"
t_end

t_begin "--list ranks measured skills weakest first"
assert_exit 0 tune --list
assert_contains "$(printf '%s' "$T_OUT" | sed -n 1p)" "learn: with_skill 50%"
assert_contains "$(printf '%s' "$T_OUT" | sed -n 3p)" "adr: with_skill 90%"
assert_contains "$T_OUT" "3 measured skills"
t_end

t_begin "a gain past the margin keeps the edit as a patch and never touches the kit"
before="$(git -C "$KIT" status --porcelain -- plugins)"
assert_exit 0 tune
assert_contains "$T_OUT" "skill-tune: learn: kept"
assert_contains "$T_OUT" "with_skill 50% -> 90%"
p="$(find "$d/out" -name candidate.patch | head -1)"
assert_contains "$(cat "$p")" "+- Check the result before reporting it."
assert_contains "$(cat "$p")" "plugins/bearing/skills/learn/SKILL.md"
assert_contains "$(cat "$(dirname "$p")/report.md")" "The failed cases skipped the final check."
assert_eq "$before" "$(git -C "$KIT" status --porcelain -- plugins)" "kit unchanged"
t_end

t_begin "the copy and the skill as it is are measured at the same time"
fresh_out
: > "$d/when.log"
STUB_WHEN="$d/when.log" assert_exit 0 tune --skill learn --repeat 2
assert_contains "$T_OUT" "(2 runs each)"
assert_eq 4 "$(grep -c '^start' "$d/when.log")" "measurements"
# every measurement started before the first one ended
first_end="$(grep '^end' "$d/when.log" | cut -d' ' -f2 | sort -n | head -1)"
last_start="$(grep '^start' "$d/when.log" | cut -d' ' -f2 | sort -n | tail -1)"
assert_eq 1 "$(python3 -c "print(int($last_start < $first_end))")" "overlapping"
p="$(find "$d/out" -name candidate.patch | head -1)"
t_end

t_begin "the patch applies to the kit as it is"
assert_exit 0 git -C "$KIT" apply --check "$p"
t_end

t_begin "the proposer runs sandboxed in the copy of the skill"
assert_contains "$(tail -1 "$d/calls.log")" '"sandbox"'
assert_contains "$(tail -1 "$d/calls.log")" "--disallowedTools Skill"
assert_contains "$(tail -1 "$d/calls.log")" "--add-dir $d/out/learn-"
assert_contains "$(tail -1 "$d/calls.log")" '"allowWrite": ["'"$d/out/learn-"
t_end

t_begin "a gain under the margin is rejected and no patch is left"
rm -rf "$d/out"
STUB_CAND=0.55 assert_exit 3 tune --skill learn
assert_contains "$T_OUT" "skill-tune: learn: rejected"
assert_eq "" "$(find "$d/out" -name candidate.patch)" "patches"
t_end

t_begin "a proposer that changes nothing is rejected without measuring"
rm -rf "$d/out"
STUB_PROPOSE=none assert_exit 3 tune --skill learn
assert_contains "$T_OUT" "no edit proposed"
assert_not_contains "$T_OUT" "measured learn"
t_end

t_begin "a candidate that fails the lint is rejected without measuring"
rm -rf "$d/out"
BRG_SKILL_TUNE_LINT="false" STUB_LOG="$d/calls.log" BRG_CLAUDE="$d/claude" BRG_SKILL_TUNE_MEASURE="$d/measure" \
  assert_exit 3 python3 "$KIT/bin/skill-tune.py" --board "$board" --out "$d/out" --skill learn
assert_contains "$T_OUT" "lint failed"
assert_not_contains "$T_OUT" "measured learn"
t_end

# Held-out cases: adr's case 3 is held out. A graded workspace with a failure
# in case 1 (shown to the proposer) and one in case 3 (never shown).
hws="$(tmpdir)"
for c in "eval-1-supersede-in-house-convention:VISIBLE-FAILURE" "eval-3-proposed-not-decided:HIDDEN-FAILURE"; do
  g="$hws/adr/iteration-1/${c%%:*}/with_skill/run-1"; mkdir -p "$g"
  printf '{"expectations": [{"text": "%s", "passed": false, "evidence": "e"}], "summary": {"pass_rate": 0.0}}\n' "${c#*:}" > "$g/grading.json"
done
htune() {
  BRG_SKILL_EVALS_WS="$hws" STUB_LOG="$d/calls.log" BRG_CLAUDE="$d/claude" BRG_SKILL_TUNE_MEASURE="$d/measure" \
    BRG_SKILL_TUNE_LINT="true" python3 "$KIT/bin/skill-tune.py" --board "$board" --out "$d/out" --skill adr "$@"
}

t_begin "the proposer is told the failures of tuned cases only, never a held-out one"
fresh_out; : > "$d/calls.log"
STUB_HELD_BASE=0.8 STUB_HELD_CAND=0.9 assert_exit 0 htune
assert_contains "$(cat "$d/calls.log")" "VISIBLE-FAILURE"
assert_not_contains "$(cat "$d/calls.log")" "HIDDEN-FAILURE"
t_end

t_begin "the proposer works on a bare copy of the skill and cannot read any evals folder"
last_call="$(cat "$d/calls.log")"  # the prompt spans lines
assert_contains "$last_call" "$d/out/adr-"
assert_contains "$last_call" "/proposal/adr"
assert_contains "$last_call" "$KIT/evals"
t_end

t_begin "a held-out case that holds lets a winning edit through and is reported"
assert_contains "$T_OUT" "held-out cases (never shown to the proposer) 80% -> 90%"
assert_contains "$T_OUT" "skill-tune: adr: kept"
t_end

t_begin "a held-out case that falls rejects the edit even when the tuned cases win"
fresh_out
STUB_HELD_BASE=0.8 STUB_HELD_CAND=0.6 assert_exit 3 htune
assert_contains "$T_OUT" "held-out cases (never shown to the proposer) 80% -> 60%"
assert_contains "$T_OUT" "the held-out cases fell"
assert_eq "" "$(find "$d/out" -name candidate.patch)" "patches"
t_end

t_begin "a skill without a held-out case says the verdict rests on the cases the proposer saw"
fresh_out
assert_exit 0 tune --skill learn
assert_contains "$T_OUT" "no held-out case"
t_end

t_begin "an unknown skill fails"
assert_exit 1 tune --skill no-such-skill
assert_contains "$T_OUT" "no-such-skill"
t_end

t_summary
