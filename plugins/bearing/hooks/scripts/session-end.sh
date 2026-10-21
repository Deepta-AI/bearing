#!/usr/bin/env bash
# SessionEnd: refresh docs/progress/<ID>.md from the checkpoint so a teammate
# sees where this task stands after the engineer commits and pushes. Never
# commits. Branches without a task id are left alone. Always exits 0; a skip
# or failure is logged as `session-end not-run <reason>` when a state dir exists.
set -u
# No program runs before lib.sh resets the environment, so no dirname here;
# the next script starts with "$BASH" from ${0%/*}, never found on PATH.
# shellcheck source=lib.sh
case "$0" in (*/*) . "${0%/*}/lib.sh" ;; (*) . ./lib.sh ;; esac
root="$(repo_root)" || exit 0
[ -n "$root" ] || exit 0
[ -d "$root/.bearing" ] || exit 0
guard="$(cd "${0%/*}/../../bin" && pwd)/brg-guard"
skip() { # skip <reason>: a gates.log line through brg-guard log (never through a link or into a FIFO)
  [ -d "$root/.bearing/state" ] || exit 0
  ( cd "$root" && "$BASH" "$guard" log session-end not-run "$1" ) >/dev/null 2>&1
  exit 0
}
# Hooks run outside the sandbox and the working tree is the agent's: every
# read here is a regular file opened without following a link and without
# blocking on a FIFO (safe_cat, progress.py show), every write goes through
# progress.py write (docs/progress opened link-free, temp plus rename) or
# brg-guard state-write, and nothing is copied: the rehearsal is a dry run
# that prints the new text.
safe_cat() { # safe_cat <file>: its text when it is a regular file; nothing otherwise
  python3 -I -S -c 'import os, sys
try:
    fd = os.open(sys.argv[1], os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    if os.fstat(fd).st_mode & 0o170000 == 0o100000:
        sys.stdout.write(os.read(fd, 65536).decode("utf-8", "replace"))
except OSError:
    pass' "$1" 2>/dev/null
}
branch="$(current_branch)"
task="$(task_id_from_branch)"; [ -n "$task" ] || skip "no task id on branch"
kit="${0%/*}/../.."
prog="$kit/skills/session-handoff/scripts/progress.py"
"$BASH" "$kit/bin/brg-session" checkpoint >/dev/null 2>&1
bf="$(printf '%s' "$branch" | tr '/' '_')"
cp_text="$(safe_cat "$root/.bearing/state/$bf.checkpoint.md")"
[ -n "$cp_text" ] || skip "no checkpoint"
nxt="$(printf '%s\n' "$cp_text" | sed -n 's/^Next (from state file): //p')"
if [ -z "$nxt" ] || [ "$nxt" = none ]; then nxt="$(printf '%s\n' "$cp_text" | sed -n 's/^Next flow step: //p')"; fi
if [ -z "$nxt" ] || [ "$nxt" = none ] || [ "$nxt" = unknown ]; then skip "no next step"; fi
cd "$root" || skip "cannot enter repo root"
mark="$bf.progress-next"
cur_text="$(python3 -I "$prog" show --task "$task" 2>/dev/null)"; rc=$?
case "$rc" in
  (0) ;;
  (3) cur_text="" ;;
  (*) skip "progress file is not a regular file" ;;
esac
if [ "$rc" -eq 0 ]; then
  status="$(printf '%s\n' "$cur_text" | sed -n 's/^- Status: *//p' | head -1)"
  case "$status" in merged|abandoned) skip "closed task";; esac
  cur="$(printf '%s\n' "$cur_text" | awk '/^## Next/{f=1;next} /^## /{f=0} f && !/^<!--/ && NF {sub(/^- /,""); print; exit}')"
  last="$(safe_cat "$root/.bearing/state/$mark")"; last="${last%
}"
  # keep a person-written Next: overwrite only a placeholder or our own last value
  case "$cur" in ''|none|unknown) ;; *) [ "$cur" = "$last" ] || exit 0;; esac
  # progress.py re-renders from the template, so a line a person added outside
  # its fields would be lost. Rehearse with --dry-run (it prints the new text);
  # if any non-empty line (other than the Next items, Branch and Updated, which
  # the write replaces) is missing from it, leave the file alone.
  new_text="$(python3 -I "$prog" write --task "$task" --branch "$branch" --next "$nxt" --dry-run 2>/dev/null)" \
    || skip "progress.py write failed"
  lost=0
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    printf '%s\n' "$new_text" | grep -qxF -- "$line" || { lost=1; break; }
  done <<EOF
$(printf '%s\n' "$cur_text" | awk '/^## /{nx=($0 ~ /^## Next[[:space:]]*$/)} nx && !/^## / {next} /^- (Updated|Branch):/ {next} NF')
EOF
  [ "$lost" -eq 0 ] || skip "would drop lines"
fi
python3 -I "$prog" write --task "$task" --branch "$branch" --next "$nxt" >/dev/null 2>&1 \
  || skip "progress.py write failed"
printf '%s\n' "$nxt" | "$BASH" "$guard" state-write put "$mark" >/dev/null 2>&1
exit 0
