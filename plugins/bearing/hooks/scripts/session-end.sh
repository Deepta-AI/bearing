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
[ -d "$root/.bearing" ] || exit 0
guard="$(cd "$(dirname "$0")/../../bin" && pwd)/brg-guard"
skip() { # skip <reason>: a gates.log line through brg-guard log (never through a link or into a FIFO)
  [ -d "$root/.bearing/state" ] || exit 0
  ( cd "$root" && bash "$guard" log session-end not-run "$1" ) >/dev/null 2>&1
  exit 0
}
branch="$(current_branch)"
task="$(task_id_from_branch)"; [ -n "$task" ] || skip "no task id on branch"
kit="$(dirname "$0")/../.."
bash "$kit/bin/brg-session" checkpoint >/dev/null 2>&1
cpf="$root/.bearing/state/$(printf '%s' "$branch" | tr '/' '_').checkpoint.md"
nxt="$(sed -n 's/^Next (from state file): //p' "$cpf" 2>/dev/null)"
if [ -z "$nxt" ] || [ "$nxt" = none ]; then nxt="$(sed -n 's/^Next flow step: //p' "$cpf" 2>/dev/null)"; fi
if [ -z "$nxt" ] || [ "$nxt" = none ] || [ "$nxt" = unknown ]; then skip "no next step"; fi
cd "$root" || skip "cannot enter repo root"
pf="docs/progress/$task.md"
mark="$root/.bearing/state/$(printf '%s' "$branch" | tr '/' '_').progress-next"
if [ -f "$pf" ]; then
  status="$(sed -n 's/^- Status: *//p' "$pf" | head -1)"
  case "$status" in merged|abandoned) skip "closed task";; esac
  cur="$(awk '/^## Next/{f=1;next} /^## /{f=0} f && !/^<!--/ && NF {sub(/^- /,""); print; exit}' "$pf")"
  last="$(cat "$mark" 2>/dev/null)"
  # keep a person-written Next: overwrite only a placeholder or our own last value
  case "$cur" in ''|none|unknown) ;; *) [ "$cur" = "$last" ] || exit 0;; esac
fi
# progress.py re-renders from the template, so a line a person added outside
# its fields would be lost. Rehearse the write on a copy first; if any
# non-empty line (other than the Next items, Branch and Updated, which the
# write replaces) is missing from the result, leave the file alone.
if [ -f "$pf" ]; then
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/brg-progress.XXXXXX")" || skip "cannot make a temp dir"
  mkdir -p "$tmp/docs/progress" && cp "$pf" "$tmp/$pf" || { rm -rf "$tmp"; skip "cannot copy progress file"; }
  if ! python3 "$kit/skills/session-handoff/scripts/progress.py" write --root "$tmp" --task "$task" --branch "$branch" --next "$nxt" >/dev/null 2>&1; then
    rm -rf "$tmp"; skip "progress.py write failed"
  fi
  lost=0
  while IFS= read -r line; do
    grep -qxF -- "$line" "$tmp/$pf" || { lost=1; break; }
  done <<EOF
$(awk '/^## /{nx=($0 ~ /^## Next[[:space:]]*$/)} nx && !/^## / {next} /^- (Updated|Branch):/ {next} NF' "$pf")
EOF
  rm -rf "$tmp"
  [ "$lost" -eq 0 ] || skip "would drop lines"
fi
python3 "$kit/skills/session-handoff/scripts/progress.py" write --task "$task" --branch "$branch" --next "$nxt" >/dev/null 2>&1 \
  || skip "progress.py write failed"
printf '%s\n' "$nxt" > "$mark.tmp" && mv "$mark.tmp" "$mark"
exit 0
