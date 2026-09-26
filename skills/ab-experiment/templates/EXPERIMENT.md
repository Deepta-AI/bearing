# Experiment: <name>

<!-- Template guidance: the design of one experiment, written before any
     code runs, so the decision is read off a table fixed in advance. The
     product owner and the engineer who analyses it read it. Every comment
     says what goes there (What), what a strong entry has (Good) and an
     example (Example). Delete each comment when you fill its section. -->

Status: designed | running | analysed   Owner: <rotation>   Designed: <YYYY-MM-DD>
Flag: `<flag_name>` (docs/operations/flags.md) | tbd
Ticket: <TASK-ID> | none

## Hypothesis

<!-- What: one sentence: the change, the segment, the primary metric, the
     minimum effect and the reason.
     Good: it has a number and a segment, or it is refused.
     Example: "If we show delivery dates on the cart for returning mobile
     users, checkout completion moves by at least 1.5 points because 'when
     will it arrive' is the top cart exit survey answer." -->

If we <change> for <segment>, <primary metric> moves by at least <MDE>
because <reason>.

## Metrics

<!-- What: exactly one primary metric and one to three guardrails, each an
     event from the event sheet.
     Good: the primary is a rate or a mean per exposed unit; each guardrail
     (error rate, p95 latency, unsubscribe, refund, crash-free users) names
     the direction that means harm; a breach stops the run on its own.
     Example: "guardrail | `checkout_payment_failed` | failures per exposed
     user | 0.021 | up" -->

| Role | Event | Definition (per exposed unit) | Baseline | Harm direction |
| --- | --- | --- | --- | --- |
| primary | `<event>` | <rate or mean> | <p> | n/a |
| guardrail | `<event>` | <rate> | <value> | up |

## Sample size

<!-- What: the sample per variant from the two-proportion formula (alpha
     0.05 two-sided, power 0.8), and the weeks it takes.
     Good: computed with python3, not by hand; weeks = ceil(2n / weekly
     eligible), never under one; baseline and traffic marked assumed: when
     nobody supplied them, and every derived number carries the prefix.
     Example: "p = 0.10, d = 0.01 (10% relative); n = 14,112 per variant;
     4 weeks at 8,000 eligible a week" -->

n = 2 * (1.96 + 0.84)^2 * p * (1 - p) / d^2
p = <baseline>, d = <absolute MDE> (<relative>% relative)
n = <n> per variant, <2n> total
Weekly eligible units: <count> (<source | assumed:>)
Duration: <w> weeks, from <start> to <planned end>

## Assignment and exposure

<!-- What: the unit, the split and its hash, and the moment the exposure
     event fires.
     Good: the unit is the user id (device id when anonymous), never the
     session; exposure fires when the unit sees the difference, not when it
     is assigned; events the sheet lacks are listed for analytics-events.
     Example: "Exposure: `experiment_exposed` when the cart renders with the
     delivery date line visible" -->

- Unit: user id | device id (never the session)
- Split: control <50> / treatment <50>, `hash(unit_id + ":" + <name>) mod 100`
- Exposure: `experiment_exposed` {experiment: "<name>", variant} at <the moment the unit sees the change>
- Events to add (when the event sheet is absent): <list>

## Stopping rules

<!-- What: when the run may end: the fixed horizon, the early stops and the
     single extension.
     Good: no decision before the planned n; early stop only on a guardrail
     breach or a sample ratio mismatch; daily peeking is not a rule.
     Example: "Extend: once, by 2 weeks, only when underpowered on
     2026-11-02." -->

- Fixed horizon: no decision before <n> exposed per variant.
- Early stop: any guardrail breach; sample ratio mismatch (p < 0.001).
- Extend: once, by <w> weeks, only when underpowered at the planned end.

## Decision table

<!-- What: the outcome to decision mapping, fixed at design time.
     Good: keep the four rows; change a threshold only here and before the
     run starts, never after the results are in.
     Example: "primary up >= 1.5 points, p < 0.05, no guardrail breach |
     ship (flag on, then remove)" -->

| Outcome | Decision |
| --- | --- |
| primary up >= MDE, p < 0.05, no guardrail breach | ship (flag on, then remove) |
| primary flat or down at full sample | kill (flag off, then remove) |
| guardrail breached | kill now |
| underpowered at planned end | extend once, then kill |

## Analysis

<!-- What: a link to the analysis document once it exists, and the flag
     removal task after the decision.
     Good: the removal task id is recorded, since the flag comes out after
     the decision.
     Example: "See checkout-delivery-date-analysis.md; flag removal ENG-455." -->

See `<name>-analysis.md` once written.
