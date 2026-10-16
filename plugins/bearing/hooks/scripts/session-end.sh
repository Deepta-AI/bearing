#!/usr/bin/env bash
# SessionEnd: refresh docs/progress/<ID>.md from the checkpoint so a teammate
# sees where this task stands after the engineer commits and pushes. Never
# commits. Branches without a task id are left alone. Always exits 0; a skip
# or failure is logged as `session-end not-run <reason>` when a state dir exists.
set -u
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"
root="$(repo_root)" || exit 0
[ -n "$root" ] || exit 0
skip() { # skip <reason>
  [ -d "$root/.bearing/state" ] || exit 0
  printf '%s\tsession-end\tnot-run\t0\t%s\n' "$(date +%Y-%m-%dT%H:%M:%S)" \
    "$(printf '%s' "$1" | tr '\t\n' '  ' | cut -c1-120)" >> "$root/.bearing/state/gates.log"
  exit 0
}
branch="$(current_branch)"
task="$(task_id_from_branch)"; [ -n "$task" ] || skip "no task id on branch"
kit="$(dirname "$0")/../.."
bash "$kit/bin/brg-session" checkpoint >/dev/null 2>&1
cpf="$root/.bearing/state/$(printf '%s' "$branch" | tr '/' '_').checkpoint.md"
nxt="$(sed -n 's/^Next (from state file): //p' "$cpf" 2>/dev/null)"
if [ -z "$nxt" ] || [ "$nxt" = none ]; then nxt="$(sed -n 's/^Next flow step: //p' "$cpf" 2>/dev/null)"; fi
cd "$root" || skip "cannot enter repo root"
python3 "$kit/skills/session-handoff/scripts/progress.py" write --task "$task" --branch "$branch" --next "${nxt:-unknown}" >/dev/null 2>&1 \
  || skip "progress.py write failed"
exit 0
