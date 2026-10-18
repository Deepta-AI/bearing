---
name: model-routing
description: 'Picks the cheapest model or cascade per LLM feature that still passes its eval, from measured scores and costs, any provider. Use when asked "which model should this feature use" or "cut our LLM bill".'
argument-hint: "<feature|all> [--threshold <x>] [--candidates <id,...>] [--unattended]"
allowed-tools: Read, Write, Edit, Grep, Glob, Skill, AskUserQuestion, Bash(ls:*), Bash(make eval:*), Bash(uv run python evals/*), Bash(npx tsx@4.23.15 evals/*), Bash(python3 *skills/model-routing/scripts/route_frontier.py*), Bash(python3 *skills/llm-gateway/scripts/llm_callsites_check.py*), Bash(printenv BEARING_AUTOPILOT BEARING_NONINTERACTIVE)
---

# model-routing

The model a feature runs on is a cost decision with a quality floor. This
skill measures every candidate on the feature's own eval, simulates a
cascade where the gateway can tell a bad small answer from a good one, and
writes the cheapest route whose score still clears the bar.

## Inputs

- Features and volume: `llm/routing.yaml` routes, and calls per day from
  the gateway's `llm_calls` record (last 30 days) when the user can read
  it; else the solution doc; else the call-site inventory in step 1.
- Candidates: the three defaults (`claude-haiku-4-5`, `claude-sonnet-5-5`,
  `claude-opus-5-5`) plus `--candidates`, any provider, each a key of the
  `models:` table with a price row (source and date in a comment).
- Golden set and harness: `evals/<feature>/` from `bearing-genai:llm-eval`,
  whose harness takes `--model <key>` and writes one results file per run.
- Threshold: `--threshold`, else the acceptance threshold in
  `docs/genai/<feature>-solution.md`, else asked in step 4.
- Strategies, cascade arithmetic, budget rule: `references/strategies.md`.
- Unattended: `--unattended`, or
  `printenv BEARING_AUTOPILOT BEARING_NONINTERACTIVE` prints a value
  other than `0`. The skill then asks nothing: a missing threshold takes
  the recommended default (the current route's lower bound) and says so;
  a candidate with no price row is left out; no golden set, or a set
  below 10 labelled cases, stops the skill with one line,
  `model-routing: unattended, missing:` then the list (price row for
  <key>, golden set for <feature>, labelled cases N of 10). It never
  writes a route from a `minimal` set unattended: it prints the frontier
  and stops with this line:
  `model-routing: unattended, missing: full golden set for <feature> (N of <minimum> cases); route unchanged`.

## Steps

**Decisions first.** Before building, run `bearing:tech-decision` for the keys llm
provider and models. `bearing:tech-decision` asks only about the keys this task needs that no
accepted ADR, the request or the code already settles, one question at
a time, and records only what the user decides; a key still
awaiting an answer follows the decision protocol of the
`bearing:tech-decision` skill (references/decision-protocol.md in the
bearing plugin).

1. Features from `$1` (`all`: every route in `llm/routing.yaml`). No
   routing file: run the call-site gate,
   `python3 "${CLAUDE_PLUGIN_ROOT}/skills/llm-gateway/scripts/llm_callsites_check.py" .`,
   copy its counts line and stop with "put the calls behind
   `bearing-genai:llm-gateway` first": a route needs a gateway to live in.
   Volume per feature as Inputs says, and which source it came from.
2. Candidates: the defaults plus `--candidates`. A candidate with no
   `models:` row or no price: ask with AskUserQuestion (as the bearing
   plugin's `references/console.md` says), options "paste the price and
   its source (Recommended)" (input and output per million tokens, the
   page and the date) and "leave this candidate out". Unattended (see
   Inputs): ask nothing, leave it out and name it in the `missing:`
   line. Never fill a price from memory; Claude prices come from the
   `claude-api` skill.
3. Measure: the `llm-eval` harness once per candidate, with the override
   key: `make eval EVAL=<feature> MODEL=<key>` when the Makefile has it,
   else `uv run python evals/<feature>/run.py --model <key>` or
   `npx tsx@4.23.15 evals/<feature>/run.ts --model <key>`. Reuse a results
   file already recorded for the same eval version and model. No golden
   set: run `bearing-genai:llm-eval` first. A set at `llm-eval`'s minimum
   size is `full`; from 10 labelled cases up to it, `minimal`, and every
   decision below is provisional; under 10, stop.
4. Decide:
   `python3 "${CLAUDE_PLUGIN_ROOT}/skills/model-routing/scripts/route_frontier.py" --threshold <x> evals/<feature>/results/<run>.jsonl ...`
   (one file per candidate). It prints one `option` line per candidate
   and per cheaper-first cascade, then the `route-frontier:` line; copy
   them verbatim. Exit 2 names what to fix: a file holding two models
   means a fallback ran during that eval, so refuse the candidate and
   re-run its eval (the override now runs with no fallback); `no price`
   goes back to step 2. Exit 1: nothing meets the threshold; the route
   stays, the report says so. No threshold from Inputs: ask with
   AskUserQuestion, options "no worse than today: the current route's
   lower bound (Recommended)" and "state the threshold". Unattended (see
   Inputs): ask nothing, take the recommended option and say so.
5. Write the route in `llm/routing.yaml` `routes.<feature>`:
   `strategy: static` with the model, or `strategy: cascade` with legs
   `cascade.first` and `cascade.then`, each
   `{model: <key>, effort, max_tokens, timeout_s}`, and
   `escalate_on: [invalid, refusal, max_tokens]`. Each leg carries its own `effort` (null for Haiku 4.5),
   `max_tokens` and `timeout_s`; a leg never inherits the route's tier,
   whose `effort` Haiku 4.5 rejects with a 400. The evidence as a
   comment (the `route-frontier:` line, date, eval version);
   `budget_usd_month` by the rule in `references/strategies.md`, with an
   alert at 80 percent through `bearing:observability`. A gateway built
   before the cascade path: add it from `bearing-genai:llm-gateway`'s
   templates (one escalation, `llm_escalation_total{feature}`, both calls
   recorded) with its three cascade tests, and run them. Update an
   existing gateway's routing schema to the leg shape (`model`, `effort`,
   `max_tokens`, `timeout_s`) too, or it rejects the new legs at startup.
6. Report `docs/genai/routing.md`: one row per feature with the chosen
   route, lower bound and threshold, cost per 1,000, monthly estimate at
   current volume next to the current route's, `full` or `minimal`, and
   the re-run date (when a model id or a price changes, or 90 days).
7. Print the contract.

## Output contract

```
## Model routing: <feature>
candidates: <K> (<ids>), golden set <N> cases (<full | minimal>)
<route_frontier.py option lines, verbatim>
chosen: <name>, lower <L> >= threshold <X>, $<C> per 1k, p95 <P> ms
route: llm/routing.yaml routes.<feature> strategy <static|cascade>, budget $<B>/month, alert at 80%
monthly estimate: $<M> at <V> requests/day (was $<W>)
re-run: when a model id or price changes, or by <date + 90 days>
report: docs/genai/routing.md
```

`minimal` adds "provisional" to the chosen line. Exit 1 prints
`chosen: none meets threshold <X>; route unchanged`.

## Gotchas

- A fallback during an eval run invalidates the candidate: its file
  scores two models. Re-run it; never drop the foreign rows and score
  the rest.
- Price rows carry source and date. A price changes; the route's
  evidence comment and the re-run date make the next run due.
- Haiku 4.5 takes no `effort` (the `claude-api` skill's thinking table);
  its tier sets `effort: null` and thinking, if wanted, is
  `budget_tokens`. Check the skill before a template sets either.
- A cascade's p95 is the escalated path's: both calls in series.
- Never route on a `minimal` set without saying provisional.
- `valid` is only what the gateway can check at call time. A cascade
  simulated on a semantic grader shows a saving production never sees.
- Two means that differ are not a result; the frontier uses the
  interval's lower bound for that reason.
