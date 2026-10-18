#!/usr/bin/env bash
# tests/unit/session_state_nofollow.sh: the precompact snapshot and
# brg-session's checkpoint and timeline writes run from hooks, outside the
# sandbox, into .bearing/state, which the agent can write. So none of them
# writes through a planted link (at the name, at a temporary name or at the
# state directory), through a hard link, or blocks on a FIFO; the timeline
# still rotates past its size cap. bash 3.2 safe.
set -u
. "$(dirname "$0")/../lib/assert.sh"
S="$KIT/plugins/bearing/bin/brg-session"
HS="$KIT/plugins/bearing/hooks/scripts"
# within <seconds> <cmd...>: 0 when the command ended in time, 1 when it had to be killed.
within() {
  local s="$1" p i=0; shift
  "$@" < /dev/null > /dev/null 2>&1 & p=$!
  while kill -0 "$p" 2>/dev/null; do
    if [ "$i" -ge $((s*10)) ]; then kill "$p" 2>/dev/null; wait "$p" 2>/dev/null; return 1; fi
    sleep 0.1; i=$((i+1))
  done
  wait "$p" 2>/dev/null; return 0
}
newrepo() { # repo: a Bearing repository on feature/ABC-1-thing; st its state directory
  repo="$(tmpdir)"; st="$repo/.bearing/state"; out="$(tmpdir)"
  git -C "$repo" init -q -b main
  git -C "$repo" -c user.email=t@example.com -c user.name=t commit -q --allow-empty -m init
  git -C "$repo" switch -q -c feature/ABC-1-thing
  mkdir -p "$st"
}
ses() { ( cd "$repo" && bash "$S" "$@" ) < /dev/null >/dev/null 2>&1; }
compact() { ( cd "$repo" && printf '{"session_id":"s1","trigger":"auto"}' | bash "$HS/precompact.sh" ) >/dev/null 2>&1; }
regular() { [ -f "$1" ] && [ ! -L "$1" ] && echo 1; }
absent() { [ -e "$1" ] && echo present || echo absent; }
cp_name=feature_ABC-1-thing.checkpoint.md
cm_name=feature_ABC-1-thing.compact.md

t_begin "a checkpoint link, at the name or at the temporary name, is never followed"
newrepo
printf 'secret\n' > "$out/kept"; ln -s "$out/kept" "$st/$cp_name"
ses checkpoint
assert_eq "secret" "$(cat "$out/kept")" "the link's target is unchanged"
assert_eq 1 "$(regular "$st/$cp_name")" "a fresh checkpoint took the link's place"
assert_contains "$(cat "$st/$cp_name")" "Branch: feature/ABC-1-thing"
rm -f "$st/$cp_name"; ln -s "$out/made" "$st/$cp_name.tmp"
ses checkpoint
assert_eq "absent" "$(absent "$out/made")" "no file made through a planted .tmp link"
assert_eq 1 "$(regular "$st/$cp_name")" "the checkpoint is still written"
printf 'secret\n' > "$out/hard"; rm -f "$st/$cp_name"; ln "$out/hard" "$st/$cp_name"
ses checkpoint
assert_eq "secret" "$(cat "$out/hard")" "the hard link's other name is unchanged"
t_end

t_begin "a timeline link or hard link is never written through"
newrepo
printf 'secret\n' > "$out/kept"; ln -s "$out/kept" "$st/timeline.jsonl"
ses timeline-start --id a --skill bearing:prd
ses timeline-close --id a
assert_eq "secret" "$(cat "$out/kept")" "the link's target is unchanged"
assert_eq 1 "$(regular "$st/timeline.jsonl")" "a fresh timeline took the link's place"
assert_eq 2 "$(grep -c '"skill":"bearing:prd"' "$st/timeline.jsonl")" "start and end recorded"
rm -f "$st/timeline.jsonl"; ln -s "$out/made" "$st/timeline.jsonl"
ses timeline-start --id b --skill bearing:prd
assert_eq "absent" "$(absent "$out/made")" "no file made through a dangling link"
printf 'secret\n' > "$out/hard"; rm -f "$st/timeline.jsonl"; ln "$out/hard" "$st/timeline.jsonl"
ses timeline-start --id c --skill bearing:prd
assert_eq "secret" "$(cat "$out/hard")" "the hard link's other name is unchanged"
t_end

t_begin "a linked state directory is never written into"
newrepo
rm -rf "$st"; mkdir "$out/state"; ln -s "$out/state" "$st"
ses timeline-start --id a --skill bearing:prd
ses timeline-close --id a
ses checkpoint
compact
assert_eq "" "$(ls -A "$out/state" | tr '\n' ' ')" "nothing written in the linked directory"
t_end

t_begin "a compaction snapshot link, at the name or at the temporary name, is never followed"
newrepo
printf 'secret\n' > "$out/kept"; ln -s "$out/kept" "$st/$cm_name"
compact
assert_eq "secret" "$(cat "$out/kept")" "the link's target is unchanged"
assert_eq 1 "$(regular "$st/$cm_name")" "a fresh snapshot took the link's place"
assert_contains "$(cat "$st/$cm_name")" "Branch: feature/ABC-1-thing"
rm -f "$st/$cm_name"; ln -s "$out/made" "$st/$cm_name.tmp"
compact
assert_eq "absent" "$(absent "$out/made")" "no file made through a planted .tmp link"
assert_eq 1 "$(regular "$st/$cm_name")" "the snapshot is still written"
t_end

t_begin "a FIFO at any of these names never hangs a hook"
newrepo; mkfifo "$st/timeline.jsonl"
assert_eq 0 "$(within 8 ses timeline-start --id a --skill bearing:prd; echo $?)" "timeline append returns"
assert_eq 0 "$(within 8 ses resume --source startup; echo $?)" "resume reading the timeline returns"
rm -f "$st/timeline.jsonl"; : > "$st/timeline.jsonl"; mkfifo "$st/timeline.jsonl.1"
assert_eq 0 "$(within 8 ses timeline-recent; echo $?)" "reading a rotated timeline FIFO returns"
rm -f "$st/timeline.jsonl.1"
rm -f "$st/$cp_name"; mkfifo "$st/$cp_name"
assert_eq 0 "$(within 8 ses checkpoint; echo $?)" "checkpoint returns"
rm -f "$st/$cp_name"; mkfifo "$st/$cp_name.tmp"
assert_eq 0 "$(within 8 ses checkpoint; echo $?)" "checkpoint with a .tmp FIFO returns"
rm -f "$st/$cm_name"; mkfifo "$st/$cm_name"
assert_eq 0 "$(within 8 compact; echo $?)" "precompact returns"
rm -f "$st/$cm_name"; mkfifo "$st/$cm_name.tmp"
assert_eq 0 "$(within 8 compact; echo $?)" "precompact with a .tmp FIFO returns"
t_end

t_begin "the timeline still rotates past its cap"
newrepo
i=0; : > "$st/timeline.jsonl"
while [ $i -lt 600 ]; do printf '%01000d\n' 0 >> "$st/timeline.jsonl"; i=$((i+1)); done
ses timeline-start --id a --skill bearing:prd
assert_eq 1 "$(regular "$st/timeline.jsonl.1")" "the full log moved to .1"
assert_eq 1 "$(wc -l < "$st/timeline.jsonl" | tr -d ' ')" "the new log holds one line"
t_end
t_summary
