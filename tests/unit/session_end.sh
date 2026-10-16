#!/usr/bin/env bash
# tests/unit/session_end.sh: SessionEnd refreshes docs/progress/<ID>.md on a
# task branch, keeps person-written content, and does nothing elsewhere.
set -u
. "$(dirname "$0")/../lib/assert.sh"
H="$KIT/plugins/bearing/hooks/scripts/session-end.sh"
run() { bash -c "cd '$1' && bash '$H'"; }
nextof() { awk '/^## Next/{f=1;next} /^## /{f=0} f && !/^<!--/ && NF {sub(/^- /,""); print; exit}' "$1"; }
repo="$(tmpdir)"; git -C "$repo" init -q -b main
git -C "$repo" -c user.email=t@example.com -c user.name=t commit -q --allow-empty -m init
git -C "$repo" checkout -q -b feature/TASK-3-list; mkdir -p "$repo/.bearing/state"
sf="$repo/.bearing/state/feature_TASK-3-list.md"
pf="$repo/docs/progress/TASK-3.md"
T_IN='{"session_id":"s","reason":"exit"}'

t_begin "task branch with a next step"
printf 'Next: write the failing list test\n' > "$sf"
c0="$(git -C "$repo" rev-list --count HEAD)"
assert_exit 0 run "$repo"
assert_eq "" "$T_OUT" "stdout empty"
assert_file "$pf"
assert_contains "$(cat "$pf")" "feature/TASK-3-list"
assert_eq "write the failing list test" "$(nextof "$pf")" "next written"
assert_eq "$c0" "$(git -C "$repo" rev-list --count HEAD)" "nothing committed"
assert_eq "" "$(git -C "$repo" log --oneline -1 -- docs/progress)" "no commit touches progress"
t_end

t_begin "hook-written next is updated, other fields kept"
python3 "$KIT/plugins/bearing/skills/session-handoff/scripts/progress.py" write --root "$repo" --task TASK-3 --status "in progress" --add-done "list endpoint" --add-decision "use paging: docs/adr/0001.md" >/dev/null 2>&1
printf 'Next: wire the paging\n' > "$sf"
assert_exit 0 run "$repo"
assert_eq "wire the paging" "$(nextof "$pf")" "hook-written next replaced"
assert_contains "$(cat "$pf")" "list endpoint"
assert_contains "$(cat "$pf")" "use paging"
assert_contains "$(cat "$pf")" "Status: in progress"
t_end

t_begin "hand-written next is kept"
python3 "$KIT/plugins/bearing/skills/session-handoff/scripts/progress.py" write --root "$repo" --task TASK-3 --next "ask Priya about the cap" >/dev/null 2>&1
printf 'Next: something else\n' > "$sf"
assert_exit 0 run "$repo"
assert_eq "ask Priya about the cap" "$(nextof "$pf")" "person next kept"
t_end

t_begin "no real next step writes nothing"
kit="$(tmpdir)"; cp -R "$KIT/plugins/bearing/." "$kit/"; rm -f "$kit/bin/flow-steps.tsv"
git -C "$repo" checkout -q -b feature/TASK-4-x
rm -f "$sf" "$repo/.bearing/state/feature_TASK-4-x.md"
assert_exit 0 bash -c "cd '$repo' && bash '$kit/hooks/scripts/session-end.sh'"
assert_eq 0 "$(ls "$repo/docs/progress" | grep -c TASK-4)" "no TASK-4 file"
assert_contains "$(cat "$repo/.bearing/state/gates.log")" "session-end	not-run	0	no next step"
t_end

t_begin "merged task untouched"
git -C "$repo" checkout -q feature/TASK-3-list
python3 "$KIT/plugins/bearing/skills/session-handoff/scripts/progress.py" write --root "$repo" --task TASK-3 --status merged --next none >/dev/null 2>&1
before="$(cat "$pf")"
printf 'Next: after merge\n' > "$sf"
assert_exit 0 run "$repo"
assert_eq "$before" "$(cat "$pf")" "file unchanged"
assert_contains "$(cat "$repo/.bearing/state/gates.log")" "session-end	not-run	0	closed task"
t_end

t_begin "no task id"
git -C "$repo" checkout -q -b feat/Thing
n="$(ls "$repo/docs/progress" | wc -l | tr -d ' ')"
assert_exit 0 run "$repo"
assert_eq "$n" "$(ls "$repo/docs/progress" | wc -l | tr -d ' ')" "no new file"
assert_contains "$(cat "$repo/.bearing/state/gates.log")" "session-end	not-run	0	no task id on branch"
t_end

t_begin "repository without .bearing"
plain="$(tmpdir)"; git -C "$plain" init -q -b main
git -C "$plain" -c user.email=t@example.com -c user.name=t commit -q --allow-empty -m init
git -C "$plain" checkout -q -b feature/TASK-9-y
assert_exit 0 run "$plain"
assert_eq "" "$(git -C "$plain" status --porcelain)" "nothing created"
t_end

t_begin "outside a repository"
notrepo="$(tmpdir)"
assert_exit 0 bash -c "cd '$notrepo' && GIT_CEILING_DIRECTORIES='$notrepo' bash '$H'"
t_end
t_summary
