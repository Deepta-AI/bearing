#!/usr/bin/env bash
# tests/unit/task_set_skills.sh: the five skills cite the task-set reference,
# and each stays at 200 lines or fewer. Counts the skills; fails on zero.
# Behaviour: three repositories on one bugfix branch, progress.py write
# --repo and set print the rows in merge order, and the sibling line the
# skills print reproduces the same branch name and type in every member.
set -u
. "$(dirname "$0")/../lib/assert.sh"
R='${CLAUDE_PLUGIN_ROOT}/references/task-set.md'
n=0
t_begin "the reference exists and holds the rules"
f="$KIT/plugins/bearing/references/task-set.md"; assert_file "$f"
body="$(cat "$f")"
for h in "## Start" "## Branch names" "## State and progress" "## Merge order" "## One MR per repository" "## Finish"; do assert_contains "$body" "$h"; done
t_end
t_begin "the five skills cite it"
for s in start-task session-handoff definition-of-done merge-request autopilot; do
  n=$((n+1)); f="$KIT/plugins/bearing/skills/$s/SKILL.md"
  assert_contains "$(cat "$f")" "$R" "$s cites task-set.md"
  assert_eq 1 "$([ "$(wc -l < "$f")" -le 200 ] && echo 1 || echo 0)" "$s at most 200 lines"
done
assert_eq 5 "$n" "five skills checked"
t_end
t_begin "start-task takes --repos; definition-of-done names no item count"
st="$(cat "$KIT/plugins/bearing/skills/start-task/SKILL.md")"
assert_contains "$(printf '%s\n' "$st" | grep '^argument-hint:')" "[--repos Name,Name,...]" "argument-hint has --repos"
assert_contains "$st" 'Set: <n> repos, merge order' "start-task output contract has the Set line"
dod="$(cat "$KIT/plugins/bearing/skills/definition-of-done/SKILL.md")"
assert_contains "$dod" "the items in step 3" "Inputs counts no items"
assert_contains "$(printf '%s\n' "$dod" | grep '^allowed-tools:')" "Bash(python3 *skills/session-handoff/scripts/progress.py*)" "dod grants progress.py"
mr="$(cat "$KIT/plugins/bearing/skills/merge-request/SKILL.md")"
assert_contains "$mr" 'Set: <k> of <n>; merge after: <Name> | first' "merge-request output contract has the Set line"
t_end
flat() { tr '\n' ' ' | tr -s ' '; } # prose wraps; match phrases across line breaks
t_begin "the reference states the merge-order question, missing and no row"
ts="$(flat < "$KIT/plugins/bearing/references/task-set.md")"
assert_contains "$ts" "one type for the" "one type for the set"
assert_contains "$ts" "--type <type>" "the sibling line carries the type"
assert_contains "$ts" "whenever more than one repository is listed" "merge order confirmed whenever the set has members"
assert_contains "$ts" "\`missing\`" "documents the missing verdict"
assert_contains "$ts" "fail: no row for this repository" "documents the no-row failure"
assert_contains "$(printf '%s' "$st" | flat)" "whenever more than one repository is listed" "start-task asks whenever more than one is listed"
assert_contains "$(printf '%s' "$mr" | flat)" "exits 1 while a sibling is not cloned yet" "merge-request expects the early non-zero exit"
t_end

P="$KIT/plugins/bearing/skills/session-handoff/scripts/progress.py"
sibling_branch() { # sibling_branch <template>: fill the placeholders, run the start-task argument rules, print the branch
  local line a typ=feature id='' name='' prev=''
  line="$(printf '%s' "$1" | sed -e 's/<ID>/ABC-40/g' -e 's/<Name>/FixLogin/g' -e 's/<type>/bugfix/g' -e 's/<list>/Infra,Api,Web/g')"
  line="${line#*start-task }"
  for a in $line; do
    case "$prev" in (--type) typ="$a"; prev=''; continue;; (--repos) prev=''; continue;; esac
    case "$a" in
      (--type|--repos) prev="$a";;
      (*) if [ -z "$id" ]; then id="$a"; elif [ -z "$name" ]; then name="$a"; fi;;
    esac
  done
  printf '%s/%s-%s' "$typ" "$id" "$name"
}
t_begin "three repositories on one bugfix branch: set rows in order, siblings reproduce the branch"
parent="$(tmpdir)"; br="bugfix/ABC-40-FixLogin"; k=0
for r in Infra Api Web; do
  git -C "$parent" init -q -b develop "$r"
  git -C "$parent/$r" config user.name t; git -C "$parent/$r" config user.email t@example.com
  git -C "$parent/$r" commit -q --allow-empty -m init; git -C "$parent/$r" switch -q -c "$br"
  k=$((k+1))
done
assert_eq 3 "$k" "three repositories made"
web="$parent/Web"
assert_exit 0 python3 "$P" write --root "$web" --task ABC-40 --title FixLogin --criteria 1 --next s \
  --repo "1. Infra (../Infra)" --repo "2. Api (../Api)" --repo "3. Web (.)"
assert_exit 0 python3 "$P" set --root "$web" --task ABC-40
rows="$(printf '%s\n' "$T_OUT" | grep -E '^[0-9]+\. ' | cut -d' ' -f2 | tr '\n' ' ')"
assert_eq "Infra Api Web " "$rows" "rows in merge order"
assert_contains "$(printf '%s\n' "$T_OUT" | grep '^3\. Web \.:')" "(this repository)" "the . row is this repository"
assert_not_contains "$(printf '%s\n' "$T_OUT" | grep '^1\. Infra')" "(this repository)" "a sibling row is not"
assert_contains "$T_OUT" "set: 3 repos" "three rows counted"
tpl="$(printf '%s\n' "$st" | grep '^Set: ' | sed 's/.*run in each sibling: //')"
assert_contains "$tpl" "start-task " "start-task prints a sibling line"
bt='`'; tpls="$tpl"
for f in SKILL.md references/review-smoke-and-mr.md; do
  t="$(flat < "$KIT/plugins/bearing/skills/autopilot/$f" | grep -o "${bt}start-task <ID>[^${bt}]*${bt}" | head -1 | tr -d "$bt")"
  assert_contains "$t" "start-task <ID>" "autopilot $f prints a sibling line"
  tpls="$tpls
$t"
done
printf '%s\n' "$tpls" > "$parent/tpls"
while IFS= read -r t; do
  for r in Infra Api Web; do
    assert_eq "$(git -C "$parent/$r" branch --show-current)" "$(sibling_branch "$t")" "sibling line [$t] gives $r's branch"
  done
done < "$parent/tpls"
t_end
t_summary
