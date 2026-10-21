#!/usr/bin/env bash
# tests/unit/route_frontier.sh: model-routing's route_frontier.py. Per
# candidate results file it prints the mean, the bootstrap lower bound, cost
# per 1,000 requests and p95 latency; for each cheaper-first pair whose small
# model's rows carry `valid` it simulates a cascade; it chooses the cheapest
# option whose lower bound meets the threshold. Exit 1 when none does, exit 2
# when it checked nothing or a file cannot be trusted.
set -u
. "$(dirname "$0")/../lib/assert.sh"
RF="$KIT/plugins/bearing-genai/skills/model-routing/scripts/route_frontier.py"
ES="$KIT/plugins/bearing-genai/skills/llm-eval/scripts/eval_stats.py"
d="$(tmpdir)"
H=claude-haiku-4-5; S=claude-sonnet-5-5; O=claude-opus-5-5
# flat <file>: its text on one line, runs of spaces as one, so a phrase
# a Markdown file wraps across lines still matches.
flat() { tr '\n' ' ' < "$1" | tr -s ' '; }

# cand <file> <model> <cost per call> <latency ms> <spec>...
# A spec is [k*]score,valid[,latency]: k rows (default 1) with that score
# (T: truncated, score null), valid true|false|- (- omits the field) and an
# optional latency for those rows. Ids run c1, c2, ... (prefix $P when set).
cand() {
  local f="$1" m="$2" c="$3" lat="$4" spec k s v l i=1 p="${P:-c}" vf tf sc
  shift 4; : > "$f"
  for spec in "$@"; do
    case "$spec" in (*'*'*) k="${spec%%\**}"; spec="${spec#*\*}" ;; (*) k=1 ;; esac
    s="${spec%%,*}"; spec="${spec#*,}"; v="${spec%%,*}"; l="$lat"
    case "$spec" in (*,*) l="${spec#*,}" ;; esac
    vf=''; [ "$v" = "-" ] || vf=",\"valid\":$v"
    tf=false; sc="$s"; [ "$s" = "T" ] && { tf=true; sc=null; }
    while [ "$k" -gt 0 ]; do
      printf '{"case_id":"%s%d","score":%s,"model":"%s","cost_usd":%s,"latency_ms":%s,"truncated":%s%s}\n' \
        "$p" "$i" "$sc" "$m" "$c" "$l" "$tf" "$vf" >> "$f"
      i=$((i+1)); k=$((k-1))
    done
  done
}

# haiku: mean 0.70, $0.20/1k; sonnet: mean 0.95, $1.00/1k; opus: mean 0.975, $3.00/1k.
cand "$d/haiku.jsonl" "$H" 0.0002 100 '28*1,-' '12*0,-'
# sonnet's two misses fall on c39 and c40, where haiku-v below is valid,
# so the cascade scores 1 on all 40.
cand "$d/sonnet.jsonl" "$S" 0.001 1000 '38*1,-' '2*0,-'
cand "$d/opus.jsonl" "$O" 0.003 2000 '39*1,-' '1*0,-'
# haiku valid on 30 of 40 with score 1 there, invalid (score 0) on c1..c10.
cand "$d/haiku-v.jsonl" "$H" 0.0002 100 '10*0,false' '30*1,true'

t_begin "cheapest passing static candidate wins"
assert_exit 0 python3 "$RF" --threshold 0.85 "$d/haiku.jsonl" "$d/sonnet.jsonl" "$d/opus.jsonl"
assert_contains "$T_OUT" "chose $S"
assert_contains "$T_OUT" "option $H: n 40, mean 0.700, lower "
assert_contains "$T_OUT" "option $S: n 40, mean 0.950, lower "
assert_contains "$T_OUT" ", \$1.00 per 1k, p95 1000 ms, truncated 0"
assert_contains "$T_OUT" "route-frontier: 3 options (0 cascades), 120 rows, chose $S (lower "
assert_contains "$T_OUT" ">= 0.85, \$1.00 per 1k)"
t_end

t_begin "a cascade that escalates only the invalid cases beats the static choice"
assert_exit 0 python3 "$RF" --threshold 0.85 "$d/haiku-v.jsonl" "$d/sonnet.jsonl"
assert_contains "$T_OUT" "option cascade $H->$S: n 40, mean 1.000, lower 1.000, \$0.45 per 1k, p95 1100 ms, truncated 0, escalated 25.0%"
assert_contains "$T_OUT" "escalated 25.0%"
assert_contains "$T_OUT" "chose cascade $H->$S"
assert_contains "$T_OUT" "route-frontier: 3 options (1 cascades), 80 rows"
t_end

t_begin "nothing passes: exit 1"
assert_exit 1 python3 "$RF" --threshold 0.99 "$d/haiku.jsonl"; assert_contains "$T_OUT" "none meets threshold 0.99"
assert_contains "$T_OUT" "route-frontier: 1 options (0 cascades), 40 rows"
t_end

t_begin "mixed models"
{ head -n 20 "$d/sonnet.jsonl"; tail -n 20 "$d/haiku.jsonl"; } > "$d/mixed.jsonl"
assert_exit 2 python3 "$RF" --threshold 0.5 "$d/mixed.jsonl"; assert_contains "$T_OUT" "a fallback ran during the eval"
assert_contains "$T_OUT" "holds models $S, $H"
t_end

t_begin "no price"
cand "$d/noprice.jsonl" or-mystral null 300 '5*1,-'
assert_exit 2 python3 "$RF" --threshold 0.5 "$d/noprice.jsonl"; assert_contains "$T_OUT" "no price for or-mystral"
t_end

t_begin "no files and empty files exit 2"
assert_exit 2 python3 "$RF" --threshold 0.5; assert_contains "$T_OUT" "nothing checked"
: > "$d/e.jsonl"; assert_exit 2 python3 "$RF" --threshold 0.5 "$d/e.jsonl"
assert_contains "$T_OUT" "nothing checked"
t_end

t_begin "no validity field: static only, said so"
assert_exit 0 python3 "$RF" --threshold 0.85 "$d/haiku.jsonl" "$d/sonnet.jsonl"; assert_contains "$T_OUT" "cascade: not simulated"
assert_contains "$T_OUT" "cascade: not simulated (no deterministic validity in the results)"
t_end

t_begin "a file whose rows are all truncated is nothing checked, not a candidate"
cand "$d/alltrunc.jsonl" "$H" 0.0002 100 '4*T,false'
assert_exit 2 python3 "$RF" --threshold 0.5 "$d/alltrunc.jsonl" "$d/sonnet.jsonl"
assert_contains "$T_OUT" "0 rows scored (4 truncated): nothing checked"
t_end

t_begin "a cascade pair with no shared case ids is not simulated"
P=x cand "$d/haiku-x.jsonl" "$H" 0.0002 100 '40*1,true'
assert_exit 1 python3 "$RF" --threshold 1.01 "$d/haiku-x.jsonl" "$d/sonnet.jsonl"
assert_contains "$T_OUT" "cascade $H->$S: not simulated (0 shared cases)"
assert_contains "$T_OUT" "(0 cascades)"
t_end

t_begin "a small model with some rows lacking valid is not a cascade's first"
cand "$d/haiku-part.jsonl" "$H" 0.0002 100 '20*1,true' '20*1,-'
assert_exit 0 python3 "$RF" --threshold 0.85 "$d/haiku-part.jsonl" "$d/sonnet.jsonl"
assert_contains "$T_OUT" "cascade $H->$S: not simulated (20 rows without valid)"
assert_contains "$T_OUT" "chose $H"
t_end

t_begin "only the larger model carries valid: the cascade is not simulated, said so"
cand "$d/sonnet-v.jsonl" "$S" 0.001 1000 '38*1,true' '2*0,true'
assert_exit 0 python3 "$RF" --threshold 0.85 "$d/haiku.jsonl" "$d/sonnet-v.jsonl"
assert_contains "$T_OUT" "cascade $H->$S: not simulated (cheaper model has no valid)"
assert_contains "$T_OUT" "(0 cascades)"
t_end

t_begin "a cascade over fewer shared cases than either file says so"
P=c cand "$d/haiku-30.jsonl" "$H" 0.0002 100 '30*1,true'
P=c cand "$d/s25.jsonl" "$S" 0.001 1000 '25*1,-'
P=x cand "$d/s10.jsonl" "$S" 0.001 1000 '10*1,-'
cat "$d/s25.jsonl" "$d/s10.jsonl" > "$d/sonnet-35.jsonl"
assert_exit 0 python3 "$RF" --threshold 0.5 "$d/haiku-30.jsonl" "$d/sonnet-35.jsonl"
assert_contains "$T_OUT" "cascade $H->$S: note: simulated on 25 shared cases ($H has 30, $S has 35)"
assert_contains "$T_OUT" "option cascade $H->$S: n 25,"
assert_exit 0 python3 "$RF" --threshold 0.85 "$d/haiku-v.jsonl" "$d/sonnet.jsonl"
assert_not_contains "$T_OUT" "shared cases ("
t_end

t_begin "a truncated share over --max-truncated makes a candidate ineligible"
cand "$d/haiku-t.jsonl" "$H" 0.0002 100 '36*1,-' '4*T,-'
assert_exit 0 python3 "$RF" --threshold 0.85 "$d/haiku-t.jsonl" "$d/sonnet.jsonl"
assert_contains "$T_OUT" "option $H: n 36, mean 1.000, lower 1.000, \$0.20 per 1k, p95 100 ms, truncated 4, ineligible (truncated 0.100 > 0.05)"
assert_contains "$T_OUT" "chose $S"
assert_exit 0 python3 "$RF" --threshold 0.85 --max-truncated 0.1 "$d/haiku-t.jsonl" "$d/sonnet.jsonl"
assert_contains "$T_OUT" "chose $H"
t_end

t_begin "p95 is the nearest rank over every row"
P=c cand "$d/lat.jsonl" "$S" 0.001 0 \
  1,-,10 1,-,20 1,-,30 1,-,40 1,-,50 1,-,60 1,-,70 1,-,80 1,-,90 1,-,100 \
  1,-,110 1,-,120 1,-,130 1,-,140 1,-,150 1,-,160 1,-,170 1,-,180 1,-,190 1,-,200 \
  1,-,210 1,-,220 1,-,230 1,-,240 1,-,250 1,-,260 1,-,270 1,-,280 1,-,290 1,-,300 \
  1,-,310 1,-,320 1,-,330 1,-,340 1,-,350 1,-,360 1,-,370 1,-,380 1,-,390 1,-,400
assert_exit 0 python3 "$RF" --threshold 0.5 "$d/lat.jsonl"
assert_contains "$T_OUT" "p95 380 ms"
t_end

t_begin "a truncated small-model answer escalates and both calls are paid"
cand "$d/haiku-tv.jsonl" "$H" 0.0002 100 '4*T,false' '36*1,true'
assert_exit 0 python3 "$RF" --threshold 0.85 --max-truncated 0.2 "$d/haiku-tv.jsonl" "$d/sonnet.jsonl"
assert_contains "$T_OUT" "option cascade $H->$S: n 40, mean 1.000, lower 1.000, \$0.30 per 1k, p95 1100 ms, truncated 0, escalated 10.0%"
t_end

t_begin "two files for one model are refused"
assert_exit 2 python3 "$RF" --threshold 0.5 "$d/haiku.jsonl" "$d/haiku-v.jsonl"
assert_contains "$T_OUT" "$H is in both"
t_end

t_begin "a malformed row is refused with its line"
printf '{"case_id":"a","score":1.5,"model":"m","cost_usd":0.1,"latency_ms":1}\n' > "$d/bad.jsonl"
assert_exit 2 python3 "$RF" --threshold 0.5 "$d/bad.jsonl"; assert_contains "$T_OUT" "line 1"
printf '{"case_id":"a","score":1,"model":"m","cost_usd":0.1}\n' > "$d/nolat.jsonl"
assert_exit 2 python3 "$RF" --threshold 0.5 "$d/nolat.jsonl"; assert_contains "$T_OUT" "latency_ms"
t_end

t_begin "parity: the same fixture and seed give the same lower bound as eval_stats.py"
cand "$d/par.jsonl" "$S" 0.001 500 '1,-' '0,-' '1,-' '1,-' '0,-' '1,-' '1,-' '1,-' '0,-' '1,-' '1,-' '1,-' 'T,-'
es="$(python3 "$ES" summary "$d/par.jsonl" --seed 3 --resamples 500 2>&1)"
lo="$(printf '%s' "$es" | sed -n 's/.*95% CI \[\([0-9.]*\),.*/\1/p')"
assert_contains "$es" "eval-stats: 12 cases (1 truncated, excluded)"
assert_exit 0 python3 "$RF" --threshold 0.1 --max-truncated 0.1 --seed 3 --resamples 500 "$d/par.jsonl"
assert_contains "$T_OUT" "option $S: n 12, mean 0.750, lower $lo,"
es7="$(python3 "$ES" summary "$d/haiku.jsonl" 2>&1)"; lo7="$(printf '%s' "$es7" | sed -n 's/.*95% CI \[\([0-9.]*\),.*/\1/p')"
assert_exit 1 python3 "$RF" --threshold 0.99 "$d/haiku.jsonl"
assert_contains "$T_OUT" "lower $lo7,"
t_end

t_begin "the gateway templates carry the cascade and its tests"
for g in gateway-python.md gateway-typescript.md; do
  t="$(cat "$KIT/plugins/bearing-genai/skills/llm-gateway/templates/$g")"
  for want in llm_escalation_total escalate_on; do assert_contains "$t" "$want" "$g"; done
done
t="$(cat "$KIT/plugins/bearing-genai/skills/llm-gateway/templates/gateway-python.md")"
for want in test_cascade_escalates_once test_escalation_counted test_no_escalation_when_valid test_model_override_skips_fallback; do
  assert_contains "$t" "$want"
done
t="$(flat "$KIT/plugins/bearing-genai/skills/llm-gateway/templates/gateway-typescript.md")"
for want in "cascade escalates once" "escalation counted" "no escalation when valid" "model_override skips fallback"; do
  assert_contains "$t" "$want" gateway-typescript.md
done
t="$(cat "$KIT/plugins/bearing-genai/skills/llm-gateway/templates/routing.yaml")"
for want in "strategy: cascade" "escalate_on: [invalid, refusal, max_tokens]" "budget_usd_month:"; do assert_contains "$t" "$want"; done
t_end

t_begin "each cascade leg carries its own effort, max_tokens and timeout; Haiku 4.5 sends none"
t="$(cat "$KIT/plugins/bearing-genai/skills/llm-gateway/templates/routing.yaml")"
assert_contains "$t" "first: { model: claude-haiku-4-5, effort: null, max_tokens: 2048, timeout_s: 20 }"
assert_contains "$t" "then: { model: claude-sonnet-5-5, effort: medium, max_tokens: 2048, timeout_s: 60 }"
t="$(cat "$KIT/plugins/bearing-genai/skills/llm-gateway/templates/gateway-python.md")"
for want in "legs = self.routing.cascade_legs(route)" "first = legs.first if legs else self.routing.static_leg(route)" \
  "result = self._call(first.model, req, first)" "used = fb" "used = legs.then" \
  "self.accounting.record(req, used, result" "if route.effort:" "with_options(timeout=route.timeout_s)"; do
  assert_contains "$t" "$want" gateway-python.md
done
assert_not_contains "$t" "self.accounting.record(req, route, result"
t="$(cat "$KIT/plugins/bearing-genai/skills/llm-gateway/templates/gateway-typescript.md")"
for want in "const legs = route.strategy === \"cascade\" ? this.routing.cascadeLegs(route) : null;" \
  "const first = legs ? legs.first : this.routing.staticLeg(route);" "result = await this.call(first.model, req, first);" \
  "used = fb;" "used = legs.then;" "this.accounting.record(req, used, result" "if (route.effort)" "timeout: route.timeoutS * 1000"; do
  assert_contains "$t" "$want" gateway-typescript.md
done
assert_not_contains "$t" "this.accounting.record(req, route, result"
for f in SKILL.md references/strategies.md; do
  t="$(flat "$KIT/plugins/bearing-genai/skills/model-routing/$f")"
  assert_contains "$t" "own \`effort\` (null for Haiku 4.5), \`max_tokens\` and \`timeout_s\`" "$f"
done
t_end

t_begin "an override, a static route and a models: row take the leg shape; Haiku 4.5 sends no effort (I1)"
t="$(cat "$KIT/plugins/bearing-genai/skills/llm-gateway/templates/routing.yaml")"
assert_contains "$t" "effort: null                   # rejects effort: never sent, whatever the tier says"
assert_contains "$t" "leg: { model: claude-haiku-4-5, effort: null, max_tokens: 1024, timeout_s: 20 }"
assert_contains "$t" "  # sonnet-low:"
assert_contains "$t" "  #   id: claude-sonnet-5-5"
for g in gateway-python.md gateway-typescript.md; do
  t="$(flat "$KIT/plugins/bearing-genai/skills/llm-gateway/templates/$g")"
  assert_contains "$t" "an override to \`claude-haiku-4-5\` on a \`balanced\` route sends no \`effort\`" "$g"
done
t="$(cat "$KIT/plugins/bearing-genai/skills/llm-gateway/templates/gateway-python.md")"
for want in "first = legs.first if legs else self.routing.static_leg(route)" \
  "route = self.routing.with_model(route, req.model_override)   # a leg: the models: row's model, effort, max_tokens, timeout_s" \
  "test_model_override_uses_model_effort"; do
  assert_contains "$t" "$want" gateway-python.md
done
t="$(flat "$KIT/plugins/bearing-genai/skills/llm-gateway/templates/gateway-typescript.md")"
for want in "const first = legs ? legs.first : this.routing.staticLeg(route);" "model_override uses model effort" "same nineteen cases"; do
  assert_contains "$t" "$want" gateway-typescript.md
done
t="$(flat "$KIT/plugins/bearing-genai/skills/model-routing/SKILL.md")"
assert_contains "$t" "\`strategy: static\` with one leg, \`leg: {model: <key>, effort, max_tokens, timeout_s}\`"
t="$(flat "$KIT/plugins/bearing-genai/skills/model-routing/references/strategies.md")"
assert_contains "$t" "sonnet-low: { provider: anthropic, id: claude-sonnet-5-5, effort: low"
t_end

t_begin "the ticket-router eval fixture chooses the cascade at its threshold"
f="$KIT/evals/model-routing/files/ticket-router/evals/triage/results"
assert_exit 0 python3 "$RF" --threshold 0.85 "$f/haiku.jsonl" "$f/sonnet.jsonl" "$f/opus.jsonl"
assert_contains "$T_OUT" "chose cascade $H->$S"
f="$KIT/evals/model-routing/files/ticket-router-fallback/evals/triage/results"
assert_exit 2 python3 "$RF" --threshold 0.85 "$f/haiku.jsonl" "$f/sonnet.jsonl"
assert_contains "$T_OUT" "a fallback ran during the eval"
t_end
t_summary
