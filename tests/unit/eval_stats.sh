#!/usr/bin/env bash
# tests/unit/eval_stats.sh: llm-eval's eval_stats.py. summary gives a mean
# and a seeded percentile bootstrap interval over the rows that are not
# truncated; compare pairs two runs by case_id and calls the change better,
# worse or no difference from the interval of the paired deltas; agree
# measures a judge against person labels with Cohen's kappa. Every
# subcommand prints its count and exits 2 when it checked nothing.
set -u
. "$(dirname "$0")/../lib/assert.sh"
ES="$KIT/plugins/bearing-genai/skills/llm-eval/scripts/eval_stats.py"
d="$(tmpdir)"
row() { printf '{"case_id":"%s","score":%s,"model":"m","truncated":false}\n' "$1" "$2"; }
{ row a 1; row b 1; row c 0; row d 1
  printf '{"case_id":"e","score":null,"model":"m","truncated":true}\n'; } > "$d/a.jsonl"
: > "$d/zeros.jsonl"; : > "$d/ones.jsonl"; : > "$d/people.jsonl"; : > "$d/judge.jsonl"; : > "$d/people10.jsonl"
i=1
while [ "$i" -le 40 ]; do
  id="$(printf 'c%02d' "$i")"
  row "$id" 0 >> "$d/zeros.jsonl"; row "$id" 1 >> "$d/ones.jsonl"
  i=$((i+1))
done
{ row x 1; row y 0; } > "$d/other-ids.jsonl"
# 30 person labels, 15 pass and 15 fail; the judge turns 3 passes into fails:
# agreement 27/30 = 0.900, pe = 0.5*0.4 + 0.5*0.6 = 0.5, kappa 0.80.
i=1
while [ "$i" -le 30 ]; do
  id="$(printf 'j%02d' "$i")"
  if [ $((i % 2)) -eq 0 ]; then lab=pass; else lab=fail; fi
  jl="$lab"; case "$i" in (2|4|6) jl=fail ;; esac
  printf '{"case_id":"%s","label":"%s"}\n' "$id" "$lab" >> "$d/people.jsonl"
  printf '{"case_id":"%s","label":"%s"}\n' "$id" "$jl" >> "$d/judge.jsonl"
  [ "$i" -le 10 ] && printf '{"case_id":"%s","label":"%s"}\n' "$id" "$lab" >> "$d/people10.jsonl"
  i=$((i+1))
done

t_begin "summary: mean and an interval that holds it; truncated excluded and counted"
assert_exit 0 python3 "$ES" summary "$d/a.jsonl"
assert_contains "$T_OUT" "eval-stats: 4 cases (1 truncated, excluded), mean 0.750"
assert_contains "$T_OUT" "95% CI [0.250, 1.000]"
t_end

t_begin "compare: identical runs are no difference"
assert_exit 0 python3 "$ES" compare "$d/a.jsonl" "$d/a.jsonl"
assert_contains "$T_OUT" "eval-compare: 4 shared cases (base 0.750, new 0.750), delta +0.000, 95% CI [+0.000, +0.000]"
assert_contains "$T_OUT" "delta +0.000"; assert_contains "$T_OUT" ": no difference"
t_end

t_begin "compare: 40 shared cases all improving 0 to 1 is better; the reverse is worse and exits 1"
assert_exit 0 python3 "$ES" compare "$d/zeros.jsonl" "$d/ones.jsonl"; assert_contains "$T_OUT" "40 shared cases"; assert_contains "$T_OUT" ": better"
assert_exit 1 python3 "$ES" compare "$d/ones.jsonl" "$d/zeros.jsonl"; assert_contains "$T_OUT" ": worse"
assert_contains "$T_OUT" "delta -1.000, 95% CI [-1.000, -1.000]"
t_end

t_begin "compare: no shared ids exits 2"
assert_exit 2 python3 "$ES" compare "$d/a.jsonl" "$d/other-ids.jsonl"; assert_contains "$T_OUT" "nothing checked"
assert_contains "$T_OUT" "0 shared cases"
t_end

t_begin "compare: a case truncated on either side is not shared"
{ row a 1; row b 1; row c 0; printf '{"case_id":"d","score":0.5,"model":"m","truncated":true}\n'; } > "$d/a-trunc.jsonl"
assert_exit 0 python3 "$ES" compare "$d/a.jsonl" "$d/a-trunc.jsonl"
assert_contains "$T_OUT" "eval-compare: 3 shared cases"
t_end

t_begin "compare: a run holding more than one model is warned about; the verdict stands"
{ row a 1; row b 1; printf '{"case_id":"c","score":0,"model":"m2","truncated":false}\n'; row d 1; } > "$d/two-models.jsonl"
assert_exit 0 python3 "$ES" compare "$d/a.jsonl" "$d/two-models.jsonl"
assert_contains "$T_OUT" "eval-compare: warning: $d/two-models.jsonl holds models m, m2"
assert_contains "$T_OUT" "eval-compare: 4 shared cases"
assert_exit 0 python3 "$ES" compare "$d/a.jsonl" "$d/a.jsonl"; assert_not_contains "$T_OUT" "warning"
t_end

t_begin "agree: perfect agreement on 30 items is kappa 1.00, calibrated"
assert_exit 0 python3 "$ES" agree "$d/people.jsonl" "$d/people.jsonl"; assert_contains "$T_OUT" "kappa 1.00: calibrated"
assert_contains "$T_OUT" "eval-agree: 30 shared items, agreement 1.000"
t_end

t_begin "agree: 27 of 30 with balanced labels is kappa 0.80; a higher bar makes it uncalibrated"
assert_exit 0 python3 "$ES" agree "$d/people.jsonl" "$d/judge.jsonl"
assert_contains "$T_OUT" "eval-agree: 30 shared items, agreement 0.900, kappa 0.80: calibrated"
assert_exit 1 python3 "$ES" agree "$d/people.jsonl" "$d/judge.jsonl" --min-kappa 0.85
assert_contains "$T_OUT" "kappa 0.80: uncalibrated"
t_end

t_begin "agree: fewer than 30 shared items is uncalibrated"
assert_exit 1 python3 "$ES" agree "$d/people10.jsonl" "$d/people10.jsonl"; assert_contains "$T_OUT" "uncalibrated"
assert_contains "$T_OUT" "10 shared items"
t_end

t_begin "agree: no labelled shared items exits 2"
assert_exit 2 python3 "$ES" agree "$d/people.jsonl" "$d/a.jsonl"; assert_contains "$T_OUT" "nothing checked"
t_end

t_begin "summary: an empty file exits 2"
: > "$d/empty.jsonl"; assert_exit 2 python3 "$ES" summary "$d/empty.jsonl"; assert_contains "$T_OUT" "nothing checked"
t_end

t_begin "summary and compare: every row truncated is nothing checked, not a score"
printf '{"case_id":"a","score":null,"model":"m","truncated":true}\n{"case_id":"b","score":0,"model":"m","truncated":true}\n' > "$d/all-trunc.jsonl"
assert_exit 2 python3 "$ES" summary "$d/all-trunc.jsonl"
assert_contains "$T_OUT" "eval-stats: 0 cases (2 truncated, excluded): nothing checked"
assert_exit 2 python3 "$ES" compare "$d/all-trunc.jsonl" "$d/all-trunc.jsonl"; assert_contains "$T_OUT" "nothing checked"
t_end

t_begin "a malformed row or a duplicate case_id is refused with its line"
printf '{"case_id":"a","score":1}\n{"case_id":"a","score":0}\n' > "$d/dup.jsonl"
assert_exit 2 python3 "$ES" summary "$d/dup.jsonl"; assert_contains "$T_OUT" "duplicate case_id a"
printf '{"case_id":"a","score":1.5}\n' > "$d/range.jsonl"
assert_exit 2 python3 "$ES" summary "$d/range.jsonl"; assert_contains "$T_OUT" "line 1"
t_end

t_begin "the same seed gives the same interval"
a="$(python3 "$ES" summary "$d/a.jsonl" --seed 3)"; b="$(python3 "$ES" summary "$d/a.jsonl" --seed 3)"; assert_eq "$a" "$b"
t_end

t_begin "bootstrap parity: every copy of the bootstrap block in bearing-genai matches eval_stats.py"
# route_frontier.py (model-routing) copies the block between the markers;
# a copy that drifts gives a different interval for the same seed.
cat > "$d/parity.py" <<'PY'
import pathlib, sys
root = pathlib.Path(sys.argv[1])
def block(p):
    t = p.read_text()
    if "# bootstrap: begin" not in t:
        return None
    return t.split("# bootstrap: begin", 1)[1].split("# bootstrap: end", 1)[0]
copies = {p: block(p) for p in sorted(root.glob("*/scripts/*.py")) if block(p) is not None}
ref = block(root / "llm-eval" / "scripts" / "eval_stats.py")
bad = [str(p) for p, b in copies.items() if b != ref]
print(f"bootstrap parity: {len(copies)} copies checked, {len(bad)} differ")
sys.exit(1 if bad or not copies or not ref else 0)
PY
assert_exit 0 python3 "$d/parity.py" "$KIT/plugins/bearing-genai/skills"
assert_contains "$T_OUT" "0 differ"
assert_not_contains "$T_OUT" ": 0 copies"
t_end

t_begin "the llm-eval case 3 fixture: means 0.01 apart is no difference"
f="$KIT/evals/llm-eval/files/prompt-v2-v3/evals/answers/results"
assert_exit 0 python3 "$ES" compare "$f/v2.jsonl" "$f/v3.jsonl"
assert_contains "$T_OUT" "eval-compare: 40 shared cases"
assert_contains "$T_OUT" "delta +0.010"
assert_contains "$T_OUT" ": no difference"
t_end
t_summary
