---
name: ab-experiment
description: 'Designs and analyses an A/B test: hypothesis, primary and guardrail metrics, sample size and duration, stopping rule, decision. Use when asked to "A/B test this", "how long should it run", "is it significant".'
argument-hint: "design <name> [--flag <flag_name>] [--metric <event>] | analyse <name> [results.csv]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(ls:*), Bash(mkdir -p:*), Bash(date:*), Bash(python3 -c:*)
---

# ab-experiment

A flag decides who sees the change; an experiment decides whether the
change was worth it. The hypothesis carries a number before any code
runs, and the decision is read off a table written at design time.

Most wrong answers here are not bad statistics. They are the right
formula fed the wrong population: blended numbers from a README, weekly
visits counted as distinct people, exposure logged where it cannot be
joined or where the treatment itself decides who is counted. Read the
code and the data before the formula.

Not this: the `feature-flags` skill adds the flag; the
`analytics-events` skill designs the wider event sheet. This skill only
uses both, and names them as skills, never as commands.

## Inputs

- mode and name: `$ARGUMENTS`; if absent, ask one question.
- flag: `--flag`; if absent, the row in `docs/operations/flags.md`
  whose name contains the experiment name; if absent, the doc says
  `flag: tbd` and the report says it must be added (the `feature-flags`
  skill). An existing flag with a different purpose is not this flag.
- primary metric: `--metric`; if absent, an event from
  `docs/analytics/EVENT_SHEET.md`; if absent, ask once: "which event
  counts as success for one exposed user?".
- baseline rate and eligible units: from the repository's own data
  (funnel exports, reach or unique-visitor reports) for the segment the
  test targets, before any number in a README or a ticket; numbers the
  user pastes win over both. If none exist, `assumed: p=0.10,
  5000/week` and every derived number carries the `assumed:` prefix.
- data retention: ADRs or docs on how long raw events are kept
  (grep `retention`, `days`, `delete` under `docs/`).
- calendar and operations: sales, launches, code or config freezes,
  other experiments on the same surface (grep `freeze`, `sale`,
  `calendar`, `launch` under `docs/`), and how a flag is switched off
  (runtime, or config plus restart or deploy).
- assignment and exposure code: the flag module and the code that fires
  the exposure event (grep the exposure event name).
- event sheet: `docs/analytics/EVENT_SHEET.md`; present: rows appended;
  absent: the events are listed in the experiment doc under "Events to
  add" and the report names the `analytics-events` skill.
- results for `analyse`: `$2`, a CSV of counts per variant (and per
  segment when present), plus any note on how it was produced (a README
  beside it, the query); if absent, ask once for the two counts per
  variant.
- experiment docs: `docs/experiments/`; created with `mkdir -p`.
- templates in this skill: `templates/EXPERIMENT.md`, `templates/analysis.md`.

## Steps

1. `design <name>`: kebab-case name. `docs/experiments/<name>.md` already
   present: stop with "exists; run analyse or choose another name".
   Design only: no feature code, no flag turned on.
2. Population. Name the segment the change reaches (platform, page,
   signed-in or not) and take the baseline and traffic for that segment
   only. A blended all-platform rate is the wrong baseline for a
   mobile-only change. Say which rows and weeks you used. The baseline
   must be in the primary metric's own unit and window: a rate per
   weekly viewer is not the rate per device within 7 days of first
   exposure (returning devices get several chances, so the per-device
   rate is usually higher and n changes). Use it as a stated
   approximation and name the query that measures the real one before
   launch.
3. Hypothesis, one sentence: "If we <change> for <segment>, <primary
   metric> moves by at least <MDE> because <reason>." Refuse a
   hypothesis without a number or a segment. "+5%" is ambiguous: read
   it as relative unless the user says points, and show both.
4. Metrics: exactly one primary, a rate or mean per exposed unit with a
   fixed outcome window ("checkout within 7 days of first exposure"),
   never per session or page view when the unit is a user or device.
   One to three guardrails (payment failure, error rate, p95 latency,
   refund, crash-free users), each with its event name, the direction
   that means harm and a breach threshold with the window it is judged
   over ("payment_failed per exposed device up by 0.5 points over a
   full day"). "Clearly worse" is not a rule: nobody can act on it.
5. Sample size, two-proportion test, alpha 0.05 two-sided, power 0.8
   (write both in the doc, not only the z constants):
   `n = 2 * (1.96 + 0.84)^2 * p * (1 - p) / d^2` per variant, `p` the
   baseline, `d` the absolute MDE. Worked: p=0.10, d=0.01: n = 14,112
   per variant. Compute with `python3 -c` and keep the command.
6. Duration, in distinct units, not visits. Weekly traffic counts a
   returning user every week, but each unit enters the test once, so
   the sum of weekly visitors overstates how fast units accrue. Use a
   distinct-unit count over a multi-week window when the repository has
   one (reach, unique devices), else say the weeks from `ceil(2n /
   weekly)` are a floor and how to measure distinct units. Add the
   outcome window to the run length. Whole weeks, never under one.
   When the test does not fit, print the smallest effect detectable in
   the time available (`d = 2.8 * sqrt(2 p (1 - p) / n)`) rather than
   pretending.
   Place the window on the calendar: a sale, launch or holiday inside it
   measures the event, not the change (different traffic, different
   intent), and the baseline was taken outside it. Start after it or end
   before it; if neither fits, say which weeks are affected and that
   the result may not hold outside them.
7. Retention. Run length plus outcome window plus analysis lag must fit
   inside raw-event retention. If not: a shorter run with the larger
   detectable effect stated, or a per-variant aggregate with no user,
   device or hashed id (a hash is still an identifier) built through
   whatever review the retention policy requires. Never plan to read
   raw events past their deletion.
8. Assignment unit. Read the flag code: a session key re-randomises the
   same person on every visit; fix it. Signed-in user id where nearly
   everyone is signed in; where many are anonymous, the device id (or
   user id falling back to device id, bucketed on one key that does not
   change at sign-in). Name the share that is anonymous and the
   cross-device leak you accept. Variant = `hash(unit_id + ":" + name)
   mod 100` against the split, sticky for the run.
9. Exposure, the step most designs get wrong:
   - fires where the unit first reaches the changed surface, in the
     targeted segment only, not in middleware on every request;
   - fires at the same point and under the same conditions in both
     arms. Control logs where the treatment would have appeared. Nothing
     the treatment does (an image load, a render, a slower page) may
     decide whether a unit is counted, or the arms stop being comparable;
   - carries the assignment unit id that the outcome events carry, so
     exposure joins to outcomes. Check the join keys in the event sheet.
   Append event rows to the sheet when present; print the count added.
10. Stopping and decision rules, fixed now. Fixed horizon at the planned
    n and end date; no decision before it; early stop only on a
    guardrail breach or a sample ratio mismatch. A stop rule is only as
    fast as the switch: if flags are read at start-up, a stop needs a
    config change and a restart, and a freeze in the window blocks it;
    say how long a stop takes, or require a runtime switch. Ship when the primary
    is up with p under 0.05 (the 95 percent CI excludes zero) and no
    guardrail is breached. The MDE sizes the test; it is not the ship
    bar: "ship only if the observed lift is at least the MDE" rejects
    about half of true effects of exactly the MDE. Kill when the primary
    is not significantly up at full sample. Extend once, by a stated
    length, only when short of n at the planned end; data collected past
    the planned end for any other reason is not read.
11. Write `docs/experiments/<name>.md` from `templates/EXPERIMENT.md`,
    Status designed (the decision rules Proposed until the owner agrees).
    Print the contract and, in the message, where every number came from.
12. `analyse <name>`: read the design for n, split, primary metric,
    outcome window and planned end. Then check the data is the thing
    the design asked for: same metric definition and outcome window,
    same unit, window ending at the planned end, units whose outcome
    window had not closed excluded. A mismatch is reported first.
13. Sample ratio mismatch before any metric: chi-square on exposed
    counts against the planned split, overall and per segment in the
    export (platform, app version, browser, day) with `python3 -c`.
    p under 0.001 overall: stop, no metric is read as a result. The
    segment that carries the imbalance points at the cause; open its
    exposure code and name the line. Say which way the bias runs (who
    is missing from which arm, and whether they convert more or less).
    A cause must differ by arm. The hash splits bots, a country or a
    browser evenly, so traffic quality alone cannot unbalance arms; when
    someone blames bots or a segment, ask why it is counted in one arm
    and not the other: that is the exposure asymmetry again, and
    filtering it out of both arms is trimming, not a fix.
14. After a mismatch the fix is symmetric exposure and a new run. The
    only valid re-read of existing data is intent-to-treat from an event
    logged identically in both arms before the variant can act, with
    assignment recomputed from the hash, and the SRM check passing on
    that population. Reweighting, trimming or imputing the broken rows
    is not a result. A balanced segment read alone is a post-hoc slice:
    report it, do not ship on it. Give no directional reading of broken
    data either ("probably a small win"): the bias has no known size.
    Before the rerun, check the design's own rules and say (without
    editing them) where they are wrong: a ship bar of "lift at least
    the MDE", a guardrail with no threshold, a traffic assumption the
    export contradicts.
15. With a clean split: exposed under n per variant is "underpowered, N
    of n". Compute rates, absolute and relative lift, two-proportion z,
    p and the 95 percent CI from the counts. Check every guardrail; one
    with no data is "not checked", never "fine". Apply the decision
    table. Write `docs/experiments/<name>-analysis.md` from
    `templates/analysis.md` with the commands used. Leave the design's
    n, MDE and rules and the flag config untouched.

## Output contract

```
## Experiment: <name> (design | analyse)
Hypothesis: <one sentence with the number>
Flag: <flag_name> | tbd (add with the feature-flags skill)
Primary: <event> per <unit> within <window> (baseline <p>, source <file, rows>)   Guardrails: N
Sample: n=<n> per variant (alpha 0.05 two-sided, power 0.8), MDE <d> abs (<r>% rel); <w> weeks at <distinct units>/week [assumed:]
Fits retention: yes | no (<what changes>)
Exposure: <where, both arms>   Unit: <key>
SRM: ok (p=<p>) | MISMATCH (p=<p>, in <segment>; cause <file:line>)   (analyse)
Result: control <p0>, treatment <p1>, lift <abs> (<rel>%), p=<p>, CI [<lo>, <hi>] | not read
Guardrails: <k> read (<b> breached), <u> not checked: no data   Power: full | underpowered (N of n)
Decision: ship | kill | extend | rerun (<reason>)
Path: docs/experiments/<name>.md [, docs/experiments/<name>-analysis.md]
```

## Gotchas

- An experiment without a flag is a launch. The variant must switch off
  without a deploy or the kill decision cannot be executed.
- Exposure that depends on the treatment (counted after an asset loads,
  after a slow render, after a click only treatment can make) drops the
  least engaged treatment units: the split skews and the lift inflates.
  Symmetric exposure prevents it; SRM detects it.
- Exposure at assignment dilutes; exposure on every request for every
  flag dilutes and inflates the table; exposure keyed on a session
  cannot be joined to a device or user outcome.
- Weekly visitors summed over weeks are not distinct units. Durations
  computed that way are too short.
- Reading the p-value daily and stopping on the first significant day
  multiplies the false-positive rate. Fixed horizon, decided at design.
- An export that runs past the planned end or counts outcomes over a
  different window is not the pre-registered read.
- Sample ratio mismatch is checked before any metric, per segment as
  well as overall; a broken split invalidates every number after it.
- A relative MDE under 5 percent on a low-traffic product takes months;
  print the weeks before anyone commits to the experiment.
- A guardrail breach stops the run even when the primary metric is up.
- The flag comes out after the decision; the doc records the removal
  task id.
