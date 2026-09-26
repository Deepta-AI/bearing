#!/usr/bin/env bash
# tests/docs/deterministic.sh: the doc generators are pure functions of the
# kit. bin/gen-skills-table.py, bin/gen-guide.py and bin/gen-devguide.py run
# twice in a copy of the kit (the checked-in files are never written) and
# every file they produce (docs/SKILLS.md, docs/WORKFLOW.md,
# site/src/data/handbook.json, devguide/src/data/internals.json, and the
# skills map in plugins/bearing/templates/repo/AGENTS.md and CLAUDE.md) must be byte
# identical between runs. The handbook site renders from that JSON, so it
# must hold one skill entry per skill directory, no comparison data, and every
# task flow in docs/flows.json, and none of the strings the kit retired:
# "the company", "Roo", and the retired skill-name prefix. When a
# generator fails (for example because another change is mid-edit) the copy
# is refreshed and the run retried once after 60 s; a second failure fails
# the test with the generator's own message rather than a weaker assertion.
set -u
. "$(dirname "$0")/../lib/assert.sh"

# kit_copy <dir>: the kit without .git (tar keeps modes and is the same on
# BSD and GNU).
kit_copy() { rm -rf "$1"; mkdir -p "$1"; (cd "$KIT" && tar --exclude=.git --exclude=node_modules -cf - .) | (cd "$1" && tar -xf -); }
# generate <copy>: both generators, output captured in GEN_OUT.
generate() { GEN_OUT="$( (cd "$1" && python3 bin/gen-skills-table.py && python3 bin/gen-guide.py && python3 bin/gen-devguide.py) 2>&1 )"; }
# jcount <json> <key>: entries under that key of the site data (0 when absent).
jcount() { python3 -c 'import json,sys
print(len(json.load(open(sys.argv[1],encoding="utf-8")).get(sys.argv[2]) or []))' "$1" "$2"; }
OUTS="docs/SKILLS.md docs/WORKFLOW.md site/src/data/handbook.json devguide/src/data/internals.json plugins/bearing/templates/repo/AGENTS.md plugins/bearing/templates/repo/CLAUDE.md"

copy="$(tmpdir)/kit"
sums_before="$(cd "$KIT" && cksum $OUTS)"
kit_copy "$copy"
t_begin "the generators run"
if ! generate "$copy"; then
  echo "generators failed once, retrying in 60 s: $(printf '%s' "$GEN_OUT" | tail -3 | tr '\n' ' ')" >&2
  sleep 60
  kit_copy "$copy"
  generate "$copy" || { _t_count; _t_fail "generators failed twice: $(printf '%s' "$GEN_OUT" | tail -5 | tr '\n' ' ')"; t_end; t_summary; }
fi
_t_count
assert_contains "$GEN_OUT" "docs: "
assert_contains "$GEN_OUT" "site data: "
assert_contains "$GEN_OUT" "stage rows written to docs/WORKFLOW.md"
assert_contains "$GEN_OUT" "devguide: "
t_end

t_begin "a second run is byte-identical"
first="$(tmpdir)"
for f in $OUTS; do mkdir -p "$first/$(dirname "$f")"; cp "$copy/$f" "$first/$f"; done
generate "$copy" || { _t_count; _t_fail "second run failed: $(printf '%s' "$GEN_OUT" | tail -3 | tr '\n' ' ')"; }
n=0
for f in $OUTS; do
  n=$((n+1))
  _t_count
  cmp -s "$copy/$f" "$first/$f" || _t_fail "$f differs between two runs"
  assert_eq 1 "$([ -s "$copy/$f" ] && echo 1)" "$f is not empty"
done
assert_eq 6 "$n" "six outputs compared"
t_end

t_begin "one entry per skill, every flow, no comparisons, no retired names"
hb="$copy/site/src/data/handbook.json"
skills="$(ls "$copy"/plugins/*/skills/*/SKILL.md | wc -l | tr -d ' ')"
assert_eq 1 "$([ "$skills" -gt 0 ] && echo 1)" "skill directories found ($skills)"
assert_eq "$skills" "$(jcount "$hb" skills)" "skills in the site data equal the skill directory count"
# Nothing published compares Bearing with other packs: no comparison data
# in the tree or the site data, and no ranking words in what the site shows.
assert_eq 0 "$([ -e "$copy/docs/comparisons.json" ] && echo 1 || echo 0)" "docs/comparisons.json in the tree"
assert_eq 0 "$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(sum(k in d for k in ("comparisons","alternates","verdictCounts")))' "$hb")" "comparison keys in the site data"
assert_eq 0 "$(grep -ciE 'stronger|strongest|best alternative|beats? (its|the) alternative' "$hb")" "ranking phrases in the site data"
assert_eq "$(python3 -c 'import json,sys; print(len(json.load(open(sys.argv[1]))["flows"]))' "$KIT/docs/flows.json")" "$(jcount "$hb" flows)" "every flow in docs/flows.json reaches the site data"
assert_eq 0 "$(grep -c 'the company' "$hb")" "site data mentions of [the company]"
# Deliberate: the one place the retired brg_ skill prefix is named, to prove
# no generated document still carries a skill under it.
assert_eq 0 "$(grep -cE '\bbrg_[a-z]' "$hb")" "site data mentions of the retired skill prefix"
assert_eq 0 "$(grep -cw 'Roo' "$hb")" "site data mentions of the retired Roo harness (whole word; Room is a database)"
assert_eq 0 "$(grep -cE '\bbrg_[a-z]' "$copy/docs/SKILLS.md" "$copy/docs/WORKFLOW.md" | awk -F: '{t+=$NF} END {print t+0}')" "SKILLS.md and WORKFLOW.md mentions of the retired skill prefix"
assert_eq "$skills" "$(sed -n '/<!-- skills-table:start -->/,/<!-- skills-table:end -->/p' "$copy/docs/SKILLS.md" | grep -c '^| `')" "SKILLS.md has one table row per skill"
assert_eq "$skills" "$(jcount "$copy/devguide/src/data/internals.json" skills)" "skills in the developer guide data equal the skill directory count"
t_end

t_begin "the checked-in files were not written by this test"
assert_eq "$sums_before" "$(cd "$KIT" && cksum $OUTS)" "docs/ and plugins/bearing/templates/repo in the kit are unchanged"
t_end

echo "deterministic: 6 generated files compared over 2 runs, $skills skills in the site data"
t_summary
