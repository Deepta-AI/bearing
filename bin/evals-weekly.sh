#!/usr/bin/env bash
# bin/evals-weekly.sh: the weekly eval run. trigger-eval, harness-eval and
# skill-evals-run (a rotating set of skills, BRG_SKILL_EVALS_MAX, default 5) run
# against this clone with the logged-in claude CLI (the subscription, never an
# API key), each into a fresh folder, then bin/eval-scoreboard.py appends a row
# to evals/scoreboard.jsonl and compares it with the last one. The maintainer
# commits the row. `make evals-timer` prints the systemd units that run this
# every week.
#
# Refuses a dirty tree (exit 2): the row records the commit it measured. The
# board itself may be uncommitted, so a row not yet committed does not block
# next week's run.
# Exits 1 when either suite or the scoreboard failed; the row is still written
# when the scoreboard had cases to write. bash 3.2 safe.
#
#   BRG_TRIGGER_EVAL  the trigger-eval command (default: python3 bin/trigger-eval.py -j 4)
#   BRG_HARNESS_EVAL  the harness-eval command (default: python3 bin/harness-eval.py)
#   BRG_SKILL_EVALS   the skill-evals-run command (default: python3 bin/skill-evals-run.py);
#                     it gets --board, --out and --max appended
#   BRG_SCOREBOARD    the board file (default: evals/scoreboard.jsonl)
set -u
kit="$(cd "$(dirname "$0")/.." && pwd)"

if [ -n "$(git -C "$kit" status --porcelain -- . ':!evals/scoreboard.jsonl')" ]; then
  echo "evals-weekly: $kit has uncommitted changes; the row would name a commit it did not measure. Commit or stash, then rerun." >&2
  exit 2
fi

out="$(mktemp -d "${TMPDIR:-/tmp}/brg-evals-weekly.XXXXXX")"
rc=0

# An override is a command line for tests (split on spaces); the default
# keeps the kit path whole, spaces and all.
trigger() {
  if [ -n "${BRG_TRIGGER_EVAL:-}" ]; then $BRG_TRIGGER_EVAL; else python3 "$kit/bin/trigger-eval.py" -j 4; fi
}
harness() {
  if [ -n "${BRG_HARNESS_EVAL:-}" ]; then $BRG_HARNESS_EVAL; else python3 "$kit/bin/harness-eval.py"; fi
}
skills() {
  if [ -n "${BRG_SKILL_EVALS:-}" ]; then $BRG_SKILL_EVALS "$@"; else python3 "$kit/bin/skill-evals-run.py" "$@"; fi
}
board="${BRG_SCOREBOARD:-$kit/evals/scoreboard.jsonl}"
BRG_TRIGGER_EVAL_OUT="$out/trigger" trigger || rc=1
BRG_HARNESS_EVAL_OUT="$out/harness" harness || rc=1
skills --board "$board" --out "$out/skill-evals" --max "${BRG_SKILL_EVALS_MAX:-5}" || rc=1

t="$(find "$out/trigger" -name results.json 2>/dev/null | head -1)"
h="$(find "$out/harness" -name results.json 2>/dev/null | head -1)"
se=""
[ -f "$out/skill-evals/summary.json" ] && se="$out/skill-evals/summary.json"
python3 "$kit/bin/eval-scoreboard.py" \
  --trigger "${t:-$out/trigger/results.json}" \
  --harness "${h:-$out/harness/results.json}" \
  ${se:+--skill-evals "$se"} \
  --board "$board" || rc=1

echo "evals-weekly: suite output kept in $out; exit $rc"
exit "$rc"
