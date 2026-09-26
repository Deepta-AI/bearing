#!/usr/bin/env bash
# tests/unit/progress.sh: skills/session-handoff/scripts/progress.py writes
# docs/progress/<ID>.md from the template (comments removed), updates only
# the named fields, indexes every file with a count per status (and reads
# unmerged branches with --refs), fails on zero files, and check catches an
# unknown status and a missing field. bash 3.2 safe.
set -u
. "$(dirname "$0")/../lib/assert.sh"
P="$KIT/skills/session-handoff/scripts/progress.py"
TODAY="$(date -u +%Y-%m-%d)"

repo() { # a git repository on a task branch, printed
  local d
  d="$(tmpdir)"
  git -C "$d" init -q -b develop
  git -C "$d" config user.name "Test Engineer"
  git -C "$d" config user.email "test@example.com"
  git -C "$d" commit -q --allow-empty -m init
  git -C "$d" switch -q -c "feature/$1"
  printf '%s' "$d"
}

t_begin "write creates the file from the template with defaults"
d="$(repo ABC-12-Refunds)"
assert_exit 0 python3 "$P" write --root "$d" --task ABC-12 --title Refunds --criteria 3 --next "write the failing refund test"
assert_contains "$T_OUT" "progress: created docs/progress/ABC-12.md"
f="$d/docs/progress/ABC-12.md"
assert_file "$f"
body="$(cat "$f")"
assert_contains "$body" "# Progress: ABC-12 Refunds"
assert_contains "$body" "- Branch: feature/ABC-12-Refunds"
assert_contains "$body" "- Status: started"
assert_contains "$body" "- Owner: Test Engineer"
assert_contains "$body" "- Started: $TODAY"
assert_contains "$body" "- Updated: $TODAY"
assert_contains "$body" "- Acceptance criteria: 3"
assert_contains "$body" "## Next
- write the failing refund test"
assert_not_contains "$body" "<!--" "the committed file"
lines="$(wc -l < "$f" | tr -d ' ')"
under=no; [ "$lines" -lt 40 ] && under=yes; assert_eq yes "$under" "file under 40 lines ($lines)"
t_end

t_begin "write updates only the named fields"
before="$(cat "$f")"
assert_exit 0 python3 "$P" write --root "$d" --task ABC-12 --status "in progress" --add-done "refund total rounds half-even" --mr https://git.example.com/mr/7
assert_contains "$T_OUT" "fields: status, mr, done"
after="$(cat "$f")"
assert_contains "$after" "- Status: in progress"
assert_contains "$after" "- MR: https://git.example.com/mr/7"
assert_contains "$after" "## Done
- refund total rounds half-even"
assert_contains "$after" "- Title: Refunds" "title kept"
assert_contains "$after" "- Acceptance criteria: 3" "criteria kept"
assert_contains "$after" "- write the failing refund test" "next kept"
assert_contains "$after" "- Ticket: none" "ticket kept"
assert_eq "$(printf '%s\n' "$before" | grep -c '^- Started:')" "$(printf '%s\n' "$after" | grep -c '^- Started:')" "one Started line"
python3 "$P" write --root "$d" --task ABC-12 --add-done "refund total rounds half-even" >/dev/null
assert_eq 1 "$(grep -c 'half-even' "$f")" "an appended item is not repeated"
assert_exit 2 python3 "$P" write --root "$d" --task ABC-12 --status "almost done"
assert_contains "$T_OUT" "unknown status 'almost done'"
t_end

t_begin "a long Done list folds so the file stays under 40 lines"
i=1
while [ "$i" -le 25 ]; do python3 "$P" write --root "$d" --task ABC-12 --add-done "step $i" >/dev/null; i=$((i+1)); done
lines="$(wc -l < "$f" | tr -d ' ')"
under=no; [ "$lines" -lt 40 ] && under=yes; assert_eq yes "$under" "file under 40 lines after 26 items ($lines)"
assert_contains "$(cat "$f")" "earlier items (see git log)"
assert_contains "$(cat "$f")" "- step 25"
t_end

t_begin "index lists every file and counts by status"
python3 "$P" write --root "$d" --task ABC-13 --title Invoices --status blocked --next "ask finance for the tax rule" --blocker "waiting on finance" >/dev/null
python3 "$P" write --root "$d" --task ABC-14 --title Export --status "in review" --next "address review comments" >/dev/null
python3 "$P" write --root "$d" --task ABC-15 --title Old --status merged >/dev/null
assert_exit 0 python3 "$P" index --root "$d"
assert_contains "$T_OUT" "task    status"
assert_contains "$T_OUT" "ABC-13  blocked"
assert_contains "$T_OUT" "ask finance for the tax rule"
assert_contains "$T_OUT" "progress: 4 tasks (0 started, 1 in progress, 1 blocked, 1 in review, 1 merged, 0 abandoned)"
assert_exit 0 python3 "$P" index --root "$d" --open
assert_not_contains "$T_OUT" "ABC-15" "--open output"
assert_contains "$T_OUT" "; 3 shown"
assert_exit 0 python3 "$P" index --root "$d" --status blocked
assert_contains "$T_OUT" "ABC-13"
assert_not_contains "$T_OUT" "ABC-14" "--status blocked output"
t_end

t_begin "index --refs reads a task that lives only on another branch"
d2="$(repo XYZ-1-Search)"
python3 "$P" write --root "$d2" --task XYZ-1 --title Search --next "index the titles" >/dev/null
git -C "$d2" add docs && git -C "$d2" commit -q -m "docs(progress): [XYZ-1] started"
git -C "$d2" switch -q develop
assert_exit 1 python3 "$P" index --root "$d2"
assert_exit 0 python3 "$P" index --root "$d2" --refs
assert_contains "$T_OUT" "XYZ-1"
assert_contains "$T_OUT" "progress: 1 tasks (1 started,"
t_end

t_begin "index on zero progress files fails and says so"
e="$(tmpdir)"
assert_exit 1 python3 "$P" index --root "$e"
assert_contains "$T_OUT" "progress: 0 progress files"
assert_exit 1 python3 "$P" check --root "$e"
assert_contains "$T_OUT" "progress check: 0 files"
t_end

t_begin "check passes good files and catches an unknown status and a missing field"
assert_exit 0 python3 "$P" check --root "$d"
assert_contains "$T_OUT" "progress check: 4 files, 0 problems"
sed 's/^- Status: blocked$/- Status: nearly there/' "$d/docs/progress/ABC-13.md" > "$d/x" && mv "$d/x" "$d/docs/progress/ABC-13.md"
grep -v '^- Owner:' "$d/docs/progress/ABC-14.md" > "$d/x" && mv "$d/x" "$d/docs/progress/ABC-14.md"
assert_exit 1 python3 "$P" check --root "$d"
assert_contains "$T_OUT" "problem: docs/progress/ABC-13.md: unknown status 'nearly there'"
assert_contains "$T_OUT" "problem: docs/progress/ABC-14.md: missing Owner"
assert_contains "$T_OUT" "progress check: 4 files, 2 problems"
t_end

t_summary
