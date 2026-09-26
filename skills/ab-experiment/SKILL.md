---
name: ab-experiment
description: 'Designs and analyses an A/B test on a feature flag: hypothesis, primary and guardrail metrics, sample size, stopping rule, decision. Use when asked to "A/B test this", "run an experiment" or "sample size".'
argument-hint: "design <name> [--flag <flag_name>] [--metric <event>] | analyse <name> [results.csv]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(ls:*), Bash(mkdir -p:*), Bash(date:*), Bash(python3 -c:*)
---

# ab-experiment

A flag decides who sees the change; an experiment decides whether the
change was worth it. The hypothesis carries a number before any code
runs, and the decision is read off a table written at design time.

Not this: `feature-flags` adds the flag; `analytics-events` designs the
wider event sheet. This skill only uses both.

## Inputs

- mode and name: `$ARGUMENTS`; if absent, ask one question.
- flag: `--flag`; if absent, the row in `docs/operations/flags.md`
  whose name contains the experiment name; if absent, the doc says
  `flag: tbd` and the report prints `feature-flags add <name>`.
- primary metric: `--metric`; if absent, an event from
  `docs/analytics/EVENT_SHEET.md`; if absent, ask once: "which event
  counts as success for one exposed user?".
- baseline rate and weekly eligible users: numbers the user pastes or a
  dashboard export; if absent, `assumed: p=0.10, 5000/week` and every
  derived number carries the `assumed:` prefix.
- event sheet: `docs/analytics/EVENT_SHEET.md`; present: rows appended;
  absent: the events are listed in the experiment doc under "Events to
  add" and the report names `analytics-events`.
- results for `analyse`: `$2`, a CSV with columns `variant,exposed,converted`;
  if absent, ask once for the two counts per variant.
- experiment docs: `docs/experiments/`; created with `mkdir -p`.
- templates in this skill: `templates/EXPERIMENT.md`, `templates/analysis.md`.

## Steps

1. `design <name>`: kebab-case name. `docs/experiments/<name>.md` already
   present: stop with "exists; run analyse or choose another name".
2. Hypothesis, one sentence: "If we <change> for <segment>, <primary
   metric> moves by at least <MDE> because <reason>." Refuse a
   hypothesis without a number or a segment.
3. Metrics: exactly one primary (a rate or a mean per exposed unit) and
   one to three guardrails (error rate, p95 latency, unsubscribe, refund,
   crash-free users), each with its event name and the direction that
   means harm. A guardrail breach is a stop rule on its own.
4. Sample size for a two-proportion test, alpha 0.05 two-sided, power
   0.8: `n = 2 * (1.96 + 0.84)^2 * p * (1 - p) / d^2` per variant, `p`
   the baseline rate, `d` the absolute MDE. Worked: p=0.10, d=0.01 (10
   percent relative): n = 2 * 7.84 * 0.09 / 0.0001 = 14,112 per variant.
   Compute with `python3 -c`. Weeks = ceil(2n / weekly eligible), never
   under one week (weekday seasonality). Print the line.
5. Assignment and exposure: the unit is the user id (device id when
   anonymous, never the session); variant = `hash(unit_id + ":" +
   name) mod 100` against the split, sticky for the run. Exposure event
   `experiment_exposed` with `experiment: string, variant: string`
   fires when the unit sees the difference, not when it is assigned.
   Primary and guardrail event names come from the sheet. Append the
   rows to the sheet when present; print the count added.
6. Stopping rules: fixed horizon at the computed n per variant; no
   decision before it; early stop only on a guardrail breach or a sample
   ratio mismatch. Decision table: primary up by at least the MDE with
   p under 0.05 and no guardrail breach = ship; primary flat or down at
   full sample = kill; underpowered at the planned end = extend once,
   then kill.
7. Write `docs/experiments/<name>.md` from `templates/EXPERIMENT.md`.
   Print the contract.
8. `analyse <name>`: read the doc for the planned n, split and primary
   metric, then the results. Sample ratio mismatch first: chi-square on
   exposed counts against the planned split with `python3 -c`; p under
   0.001 means the assignment is broken: stop, no metric is read.
   Exposed under the planned n per variant: mark "underpowered, N of n".
   Compute rates, absolute and relative lift, two-proportion z, p-value
   and the 95 percent CI. Check every guardrail. Apply the decision
   table. Write `docs/experiments/<name>-analysis.md` from
   `templates/analysis.md`.

## Output contract

```
## Experiment: <name> (design | analyse)
Hypothesis: <one sentence with the number>
Flag: <flag_name> | tbd (feature-flags add <name>)
Primary: <event> (baseline <p>)   Guardrails: N
Sample: n=<n> per variant, MDE <d> abs (<r>% rel), <w> weeks at <eligible>/week [assumed:]
Events: <k> rows added to docs/analytics/EVENT_SHEET.md | listed under Events to add
SRM: ok (p=<p>) | MISMATCH (stop)                                   (analyse)
Result: control <p0>, treatment <p1>, lift <abs> (<rel>%), p=<p>, CI [<lo>, <hi>]
Guardrails: N checked, K breached   Power: full | underpowered (N of n)
Decision: ship | kill | extend (<reason>)
Path: docs/experiments/<name>.md [, docs/experiments/<name>-analysis.md]
```

## Gotchas

- An experiment without a flag is a launch. The variant must switch off
  without a deploy or the kill decision cannot be executed.
- Exposure fires when the user sees the difference. Firing at assignment
  dilutes the effect with units that never reached the screen.
- Reading the p-value daily and stopping on the first significant day
  multiplies the false-positive rate. Fixed horizon, decided at design.
- Sample ratio mismatch is checked before any metric; a broken split
  invalidates every number after it.
- Sessions are not units. A user who lands in both variants poisons both.
- A relative MDE under 5 percent on a low-traffic product takes months;
  print the weeks before anyone commits to the experiment.
- A guardrail breach stops the run even when the primary metric is up.
- The flag comes out after the decision; the doc records the removal
  task id (`feature-flags remove <name>`).
