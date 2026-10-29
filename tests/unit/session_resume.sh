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

C="$KIT/plugins/bearing/bin/brg-config"
cf="$repo/.bearing/config.json"
# Every case that writes or depends on the project config starts from none,
# so a failed assertion in one case cannot leak a flow into the next.
cfg_reset() { rm -f "$cf"; }
# Step 1 is start-task in feature, bugfix and site alike, so the flow shows
# only at step 2: record start-task on this branch, then ask for the next.
second_step() { ran "bearing:start-task"; in_repo next-step; }

t_begin "a site repository follows the site flow on a feature branch"
cfg_reset
git -C "$repo" checkout -q -b feature/TASK-50-Landing
mkdir -p "$repo/.bearing"; printf '{"flow": "site"}\n' > "$cf"
assert_exit 0 in_repo next-step
assert_eq "$(step site 1)" "$T_OUT"
assert_eq "start-task" "$(step site 1)" "site step 1"
ran "bearing:start-task"
assert_exit 0 in_repo next-step
assert_eq "brainstorming" "$T_OUT" "site step 2"
t_end

t_begin "a bugfix branch in a site repository follows the bugfix flow"
cfg_reset
mkdir -p "$repo/.bearing"; printf '{"flow": "site"}\n' > "$cf"
git -C "$repo" checkout -q -b bugfix/TASK-51-Typo
assert_exit 0 in_repo next-step
assert_eq "$(step bugfix 1)" "$T_OUT"
assert_eq "$(step bugfix 2)" "$(second_step)" "bugfix step 2, not site"
cfg_reset
t_end

t_begin "a pretty-printed config with several keys still selects the site flow"
cfg_reset
git -C "$repo" checkout -q -b feature/TASK-52-Pricing
mkdir -p "$repo/.bearing"
jq -n '{"stack": "next-app", "workflow": "feature", "flow": "site", "tracker": "none"}' > "$cf"
assert_eq 6 "$(wc -l < "$cf" | tr -d ' ')" "jq wrote one key per line"
assert_eq "$(step site 2)" "$(second_step)" "flow key third of four"
cfg_reset
t_end

t_begin "a flow other than site, or site under another key, follows the feature flow"
cfg_reset
mkdir -p "$repo/.bearing"
for v in feature genai sites SITE; do
  git -C "$repo" checkout -q -b "feature/TASK-53-$v"
  jq -n --arg v "$v" '{"name": "x", "flow": $v}' > "$cf"
  assert_eq "$(step feature 2)" "$(second_step)" "flow $v"
done
git -C "$repo" checkout -q -b feature/TASK-53-subflow
jq -n '{"subflow": "site", "flowchart": "site"}' > "$cf"
assert_eq "$(step feature 2)" "$(second_step)" "site under another key"
cfg_reset
t_end

t_begin "brg-config set flow site round trips into next-step"
cfg_reset
git -C "$repo" checkout -q -b feature/TASK-54-Docs
assert_exit 0 bash -c "cd '$repo' && bash '$C' set stack next-app && bash '$C' set flow site"
assert_exit 0 bash -c "cd '$repo' && bash '$C' get flow"
assert_eq "site" "$T_OUT" "brg-config get"
assert_eq "next-app" "$(cd "$repo" && bash "$C" get stack)" "the other key kept"
assert_eq "$(step site 2)" "$(second_step)" "next-step reads what brg-config wrote"
cfg_reset
t_end

t_begin "highest order wins: ran steps 1 and 3, next is 4"
cfg_reset
git -C "$repo" checkout -q -b feature/TASK-20-hi
ran "bearing:$(step feature 3)"; ran "$(step feature 1)"
assert_exit 0 in_repo next-step
assert_eq "$(step feature 4)" "$T_OUT"
t_end

t_begin "flow by branch prefix"
cfg_reset
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

# A branch step whose condition already holds is skipped: new-repo once the
# repository has a commit, design-system once docs/design/tokens.json (what
# design-system updates in place) exists.
t_begin "an existing site repository skips new-repo: after brainstorming comes design-directions"
cfg_reset
git -C "$repo" checkout -q -b feature/TASK-60-Pricing
printf '{"flow": "site"}\n' > "$cf"
ran "bearing:start-task"; ran "superpowers:brainstorming"
assert_eq "new-repo" "$(step site 3)" "site step 3 is the branch step new-repo"
assert_exit 0 in_repo next-step
assert_eq "design-directions" "$T_OUT" "new-repo skipped"
assert_exit 0 in_repo resume --source startup
assert_contains "$T_OUT" "Next: design-directions."
assert_not_contains "$T_OUT" "new-repo"
t_end

t_begin "a site repository with no commit yet still gets new-repo"
r4="$(tmpdir)"; git -C "$r4" init -q -b feature/TASK-61-Site
mkdir -p "$r4/.bearing/state"; printf '{"flow": "site"}\n' > "$r4/.bearing/config.json"
( cd "$r4" && bash "$S" timeline-start --id n1 --skill bearing:start-task && bash "$S" timeline-close --id n1 &&
  bash "$S" timeline-start --id n2 --skill superpowers:brainstorming && bash "$S" timeline-close --id n2 ) >/dev/null
assert_exit 0 bash -c "cd '$r4' && bash '$S' next-step"
assert_eq "new-repo" "$T_OUT" "no commit: the scaffold step stays"
t_end

t_begin "design-system is skipped once docs/design/tokens.json exists, kept before"
cfg_reset
git -C "$repo" checkout -q -b feature/TASK-62-Brand
printf '{"flow": "site"}\n' > "$cf"
ran "bearing:design-directions"
assert_exit 0 in_repo next-step
assert_eq "design-system" "$T_OUT" "no tokens: design-system is next"
mkdir -p "$repo/docs/design"; printf '{}\n' > "$repo/docs/design/tokens.json"
assert_exit 0 in_repo next-step
assert_eq "screen-design" "$T_OUT" "tokens exist: design-system skipped"
rm -f "$repo/docs/design/tokens.json"
t_end

t_begin "only branch steps are skipped, and the flow table marks them"
assert_eq "branch" "$(awk -F'\t' '$1=="site" && $3=="new-repo" {print $4}' "$tsv")" "site new-repo is a branch step"
assert_eq "branch" "$(awk -F'\t' '$1=="site" && $3=="design-system" {print $4}' "$tsv")" "site design-system is a branch step"
assert_eq "step" "$(awk -F'\t' '$1=="greenfield" && $3=="new-repo" {print $4}' "$tsv")" "greenfield new-repo is a main-line step"
assert_eq 0 "$(awk -F'\t' '$4!="step" && $4!="branch"' "$tsv" | wc -l | tr -d ' ')" "every row has a kind"
cfg_reset
t_end

t_begin "the workflow skill reads the recorded flow before it picks one"
wf="$KIT/plugins/bearing/skills/workflow/SKILL.md"
fl="$(grep -n 'bin/brg-config" get flow' "$wf" | head -1 | cut -d: -f1)"
sl="$(grep -n '^## Steps' "$wf" | head -1 | cut -d: -f1)"
assert_eq 1 "$([ -n "$fl" ] && [ -n "$sl" ] && [ "$fl" -lt "$sl" ] && echo 1)" "brg-config get flow is read in Inputs, before the steps"
assert_contains "$(sed -n 's/^allowed-tools: //p' "$wf")" "Bash(bash *bin/brg-config*)" "granted"
t_end

t_begin "from an idea: after prd on the default branch, next is the greenfield step after it"
cfg_reset
git -C "$repo" checkout -q main
assert_exit 0 in_repo next-step
assert_eq "$(step feature 1)" "$T_OUT" "nothing ran: the feature flow"
ran "bearing:prd"
assert_exit 0 in_repo next-step
assert_eq "backlog" "$T_OUT" "prd, then backlog"
assert_eq "backlog" "$(step greenfield 3)" "greenfield step 3"
ran "bearing:backlog"
assert_exit 0 in_repo next-step
assert_eq "$(step greenfield 4)" "$T_OUT" "then step 4"
t_end

t_begin "genai-design straight after prd does not skip the main line"
git -C "$repo" checkout -q -b product/Assistant main
ran "bearing:prd"; ran "bearing-genai:genai-design"
assert_exit 0 in_repo next-step
assert_eq "backlog" "$T_OUT" "backlog is still next"
ran "bearing:backlog"
assert_exit 0 in_repo next-step
assert_eq "$(step greenfield 4)" "$T_OUT" "then step 4"
t_end

t_begin "a ticket branch stays on the feature flow even after a prd"
git -C "$repo" checkout -q -b feature/TASK-77-Offer
ran "bearing:start-task"; ran "bearing:prd"
assert_exit 0 in_repo next-step
assert_eq 0 "$(awk -F'\t' -v s="$T_OUT" '$1=="feature" && $3==s' "$tsv" | wc -l | awk '{print ($1>0)?0:1}')" "a feature step"
t_end

t_begin "the project config can name the greenfield flow"
git -C "$repo" checkout -q -b product/Start main
mkdir -p "$repo/.bearing"; printf '{"flow": "greenfield"}\n' > "$cf"
assert_exit 0 in_repo next-step
assert_eq "$(step greenfield 1)" "$T_OUT"
git -C "$repo" checkout -q -b feature/TASK-88-Slot main
ran "bearing:start-task"
assert_exit 0 in_repo next-step
assert_eq "$(step feature 2)" "$T_OUT" "a ticket branch keeps the feature flow under a greenfield config"
cfg_reset
t_end
t_summary
