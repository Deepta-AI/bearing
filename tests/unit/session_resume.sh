#!/usr/bin/env bash
# tests/unit/session_resume.sh: next step from the timeline and the resume
# block, with and without a task id; a Next: in the state file wins.
set -u
. "$(dirname "$0")/../lib/assert.sh"
S="$KIT/plugins/bearing/bin/brg-session"
repo="$(tmpdir)"; git -C "$repo" init -q -b main
git -C "$repo" -c user.email=t@example.com -c user.name=t commit -q --allow-empty -m init
git -C "$repo" checkout -q -b bugfix/TASK-9-crash; mkdir -p "$repo/.bearing/state"
in_repo() { ( cd "$repo" && bash "$S" "$@" ) }
first="$(awk -F'\t' '$1=="bugfix" && $2==1 {print $3}' "$KIT/plugins/bearing/bin/flow-steps.tsv")"
second="$(awk -F'\t' '$1=="bugfix" && $2==2 {print $3}' "$KIT/plugins/bearing/bin/flow-steps.tsv")"

t_begin "nothing ran: next is the first bugfix step"
assert_exit 0 in_repo next-step
assert_eq "$first" "$T_OUT"
t_end

t_begin "after the first step, next is the second"
in_repo timeline-start --id s --skill "bearing:$first"; in_repo timeline-close --id s
assert_exit 0 in_repo next-step
assert_eq "$second" "$T_OUT"
t_end

t_begin "resume block"
assert_exit 0 in_repo resume --source startup
assert_contains "$T_OUT" "Resume TASK-9: last ran bearing:$first. Next: $second."
assert_eq 1 "$([ "$(printf '%s\n' "$T_OUT" | wc -l)" -le 40 ] && echo 1 || echo 0)" "at most 40 lines"
t_end

t_begin "branch without an id"
git -C "$repo" checkout -q -b feat/RuntimeAndFeel
assert_exit 0 in_repo resume --source startup
assert_contains "$T_OUT" "Resume this branch: last ran nothing yet."
assert_not_contains "$T_OUT" "Resume :"
t_end

tsv="$KIT/plugins/bearing/bin/flow-steps.tsv"
step() { awk -F'\t' -v f="$1" -v o="$2" '$1==f && $2==o {print $3}' "$tsv"; }
ran() { in_repo timeline-start --id "r$RANDOM" --skill "$1" >/dev/null; in_repo timeline-close --id "$(grep -o '"session":"r[0-9]*"' "$repo/.bearing/state/timeline.jsonl" | tail -1 | sed 's/.*:"//; s/"//')"; }

t_begin "a site repository follows the site flow on a feature branch"
git -C "$repo" checkout -q -b feature/TASK-50-Landing
mkdir -p "$repo/.bearing"; printf '{"flow": "site"}\n' > "$repo/.bearing/config.json"
assert_exit 0 in_repo next-step
assert_eq "$(step site 1)" "$T_OUT"
assert_eq "start-task" "$(step site 1)" "site step 1"
ran "bearing:start-task"
assert_exit 0 in_repo next-step
assert_eq "brainstorming" "$T_OUT" "site step 2"
t_end

t_begin "a bugfix branch in a site repository follows the bugfix flow"
git -C "$repo" checkout -q -b bugfix/TASK-51-Typo
assert_exit 0 in_repo next-step
assert_eq "$(step bugfix 1)" "$T_OUT"
rm -f "$repo/.bearing/config.json"
t_end

t_begin "highest order wins: ran steps 1 and 3, next is 4"
git -C "$repo" checkout -q -b feature/TASK-20-hi
ran "bearing:$(step feature 3)"; ran "$(step feature 1)"
assert_exit 0 in_repo next-step
assert_eq "$(step feature 4)" "$T_OUT"
t_end

t_begin "flow by branch prefix"
for b in feat/x-1 bugfix/y fix/y hotfix/y other/z; do
  git -C "$repo" checkout -q -b "$b"
  case "$b" in bugfix/*|fix/*|hotfix/*) want="$(step bugfix 1)";; *) want="$(step feature 1)";; esac
  assert_exit 0 in_repo next-step
  assert_eq "$want" "$T_OUT" "$b"
done
t_end

t_begin "finished flow: no next step, resume falls back"
git -C "$repo" checkout -q -b bugfix/TASK-30-done
total="$(awk -F'\t' '$1=="bugfix"' "$tsv" | wc -l | tr -d ' ')"
ran "$(step bugfix "$total")"
assert_exit 0 in_repo next-step
assert_eq "" "$T_OUT"
assert_exit 0 in_repo resume --source startup
assert_contains "$T_OUT" "Next: see the workflow skill."
t_end

t_begin "main with nothing prints nothing and writes no checkpoint"
r3="$(tmpdir)"; git -C "$r3" init -q -b main
git -C "$r3" -c user.email=t@example.com -c user.name=t commit -q --allow-empty -m init
mkdir -p "$r3/.bearing/state"
T_OUT="$( cd "$r3" && bash "$S" resume --source startup )"
assert_eq "" "$T_OUT"
assert_eq 0 "$(ls "$r3/.bearing/state" | grep -c checkpoint)" "no checkpoint file"
t_end

t_begin "main with a timeline entry still resumes"
( cd "$r3" && bash "$S" timeline-start --id m --skill bearing:prd && bash "$S" timeline-close --id m )
T_OUT="$( cd "$r3" && bash "$S" resume --source startup )"
assert_contains "$T_OUT" "Resume this branch: last ran bearing:prd."
t_end

t_begin "long checkpoint and state file stay within 40 lines"
git -C "$repo" checkout -q bugfix/TASK-9-crash
i=0; : > "$repo/.bearing/state/bugfix_TASK-9-crash.md"
while [ $i -lt 100 ]; do echo "Next: line $i" >> "$repo/.bearing/state/bugfix_TASK-9-crash.md"; i=$((i+1)); done
assert_exit 0 in_repo resume --source startup
assert_eq 1 "$([ "$(printf '%s\n' "$T_OUT" | wc -l)" -le 40 ] && [ "$(printf '%s\n' "$T_OUT" | wc -l)" -ge 5 ] && echo 1 || echo 0)" "5 to 40 lines"
t_end
t_begin "a person-written Next: in the state file wins over the flow step"
git -C "$repo" checkout -q -b bugfix/TASK-31-next
printf '# Handoff\n\nNext: wire the retry into the client\n' > "$repo/.bearing/state/bugfix_TASK-31-next.md"
assert_exit 0 in_repo resume --source startup
assert_contains "$T_OUT" "Resume TASK-31: last ran nothing yet. Next: wire the retry into the client."
assert_not_contains "$T_OUT" "Next: $first." "the computed step is not offered"
printf '# Handoff\n\nNext: none\n' > "$repo/.bearing/state/bugfix_TASK-31-next.md"
assert_exit 0 in_repo resume --source startup
assert_contains "$T_OUT" "Next: $first." "none falls back to the flow step"
t_end
t_begin "a branch that ran genai-design follows the genai flow"
git -C "$repo" checkout -q -b feat/TASK-40-genai
ran "bearing-genai:genai-design"
assert_exit 0 in_repo next-step
assert_eq "$(step genai 3)" "$T_OUT"
assert_eq "tech-decision" "$(step genai 3)" "genai step 3"
t_end
t_begin "a bugfix branch stays on the bugfix flow after genai-design"
git -C "$repo" checkout -q -b bugfix/TASK-41-g
ran "bearing-genai:genai-design"
assert_exit 0 in_repo next-step
assert_eq "$(step bugfix 1)" "$T_OUT"
t_end
t_summary
