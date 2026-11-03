#!/usr/bin/env bash
# tests/unit/evals_data.sh: bin/evals_data.py, what the handbook's Evals page
# shows. With no scoreboard it reports what is defined and 0 measured, never
# a number; with rows it keeps the newest measurement of each skill across
# rows (the weekly rotation measures a different set each time) and lists
# every run in order. An empty kit (no evals) exits 1.
set -u
. "$(dirname "$0")/../lib/assert.sh"
ED="$KIT/bin/evals_data.py"
data() { python3 -c 'import json,sys; sys.path.insert(0, sys.argv[1]); import evals_data; print(json.dumps(evals_data.evals(sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else None), sort_keys=True))' "$KIT/bin" "$@"; }

k="$(tmpdir)"; mkdir -p "$k/evals/adr" "$k/evals/prd"
printf '[{"skill":"adr","should":["a","b","c"],"near":[{"prompt":"x","expect":"prd"},{"prompt":"y","expect":"prd"}]},{"skill":"prd","should":["d","e","f"],"near":[{"prompt":"z","expect":"adr"},{"prompt":"w","expect":"adr"}]}]\n' > "$k/evals/triggers.json"
printf '{"skill_name":"adr","evals":[{"id":1},{"id":2}]}\n' > "$k/evals/adr/evals.json"
printf '{"skill_name":"prd","evals":[{"id":1}]}\n' > "$k/evals/prd/evals.json"

t_begin "no scoreboard: what is defined, 0 measured"
assert_exit 0 python3 "$ED" --kit "$k"
assert_contains "$T_OUT" "2 skills with evals (3 cases), 10 trigger requests over 2 skills; 0 scoreboard rows, 0 skills trigger-measured, 0 measured with and without"
out="$(data "$k")"
assert_eq "[]" "$(printf '%s' "$out" | jq -c '.runs')" "no runs"
assert_eq "{}" "$(printf '%s' "$out" | jq -c '.skillsMeasured')" "nothing measured"
t_end

t_begin "rows: the newest measurement of each skill, every run in order"
b="$k/evals/scoreboard.jsonl"
printf '%s\n' \
  '{"date":"2026-11-01","commit":"aaaaaaa1111","trigger":{"cases":5,"recall":0.67,"false_rate":0.0,"limited":false,"skills":{"adr":[2,3,0,2]}},"harness":{"runs":6,"passed":5,"limited":false,"scenarios":{}},"skill_evals":{"measured":1,"skills":{"adr":{"date":"2026-11-01","cases":2,"arms":{"with_skill":{"pass_rate":0.71},"without_skill":{"pass_rate":0.71}},"margin":0.0,"result":"no difference"}}}}' \
  '{"date":"2026-11-08","commit":"bbbbbbb2222","trigger":{"cases":5,"recall":1.0,"false_rate":0.5,"limited":true,"skills":{"prd":[3,3,1,2]}},"harness":{"runs":6,"passed":6,"limited":false,"scenarios":{}},"skill_evals":{"measured":1,"skills":{"adr":{"date":"2026-11-08","cases":2,"arms":{"with_skill":{"pass_rate":0.9},"without_skill":{"pass_rate":0.6}},"margin":0.3,"result":"skill helps"}}}}' > "$b"
assert_exit 0 python3 "$ED" --kit "$k"
assert_contains "$T_OUT" "2 scoreboard rows, 2 skills trigger-measured, 1 measured with and without"
out="$(data "$k")"
assert_eq "2026-11-01 2026-11-08" "$(printf '%s' "$out" | jq -r '[.runs[].date] | join(" ")')" "runs in order"
assert_eq "aaaaaaa" "$(printf '%s' "$out" | jq -r '.runs[0].commit')" "short commit"
assert_eq "true" "$(printf '%s' "$out" | jq -r '.runs[1].limited')" "a run stopped at the limit says so"
assert_eq "0.9 0.6 skill helps" "$(printf '%s' "$out" | jq -r '.skillsMeasured.adr | "\(.arms.with_skill) \(.arms.without_skill) \(.result)"')" "the newest with/without wins"
assert_eq "2 3" "$(printf '%s' "$out" | jq -r '.triggerMeasured.adr | "\(.loaded) \(.should)"')" "adr kept from the first row"
assert_eq "1 2" "$(printf '%s' "$out" | jq -r '.triggerMeasured.prd | "\(.false) \(.near)"')" "prd from the second"
t_end

t_begin "a kit with no evals fails"
e="$(tmpdir)"; mkdir -p "$e/evals"; printf '[]\n' > "$e/evals/triggers.json"
assert_exit 1 python3 "$ED" --kit "$e"
assert_contains "$T_OUT" "0 skills with evals (0 cases), 0 trigger requests"
t_end

t_begin "the handbook carries the evals the page reads"
assert_eq "$(python3 "$ED" | sed 's/^evals_data: //; s/ skills with evals.*//')" "$(jq -r '.evals.skillsWithEvals' "$KIT/site/src/data/handbook.json")" "handbook matches the evals on disk"
t_end

t_summary
