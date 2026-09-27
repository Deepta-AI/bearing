---
name: on-call
description: 'Sets up on-call: rotation, escalation, alert routing by severity, error budget policy, handover notes, a runbook for every paging alert. Use when asked about "on-call", "who gets paged", "escalation" or "error budget".'
argument-hint: "[setup|check|handover|review] [--service <name>]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(ls:*), Bash(mkdir -p:*), Bash(date:*), Bash(promtool check:*), Bash(amtool check-config:*), Bash(git log:*), Bash(bash *bin/brg-runbook-check*)
---

# on-call

A pager is a contract between an alert and a person. This skill writes
who is on the hook, how a page climbs, what each severity does and what a
burnt error budget costs the roadmap, and it proves from the config (not
from label names) that nothing pages without a runbook.

Not this: `observability` writes the alert rules; `runbook` writes one
runbook; `incident` runs a live incident.

## Inputs

Read every one of these before writing anything. The configuration beats
the prose: when the README and a config file disagree (the paging tool,
where rules live), the config is the fact and the prose is a finding.

- Rule files Prometheus actually loads: open `prometheus.yml` (search the
  repo; often under `deploy/`) and expand each `rule_files` glob exactly,
  mapping mount paths to repo paths from its comments or the chart. A rule
  file the globs do not match (`*.yaml` does not match `x.yml`) never loads:
  its alerts cannot fire, which is a finding, not a runbook to write. No
  `prometheus.yml`: fall back to `monitoring/alerts/` and every
  `*rules*.y*ml` or `*alert*.y*ml`, and say the load set is assumed.
- Alertmanager config (`alertmanager.yml`): the route tree, the default
  receiver, `continue`, time intervals, which receivers page.
- Runbooks: `docs/runbooks/*.md`; absent means every paging alert lacks one.
- SLOs: `docs/observability/slos.md` (target, window, indicator, traffic
  volume if stated). Absent: propose 99.9 percent availability, marked
  proposed.
- Severity scale: `docs/operations/severity.md`. When it exists it is the
  routing rule; it is usually shared across teams, so a disagreement is
  proposed to its owners, never edited. Only when it is absent use: Sev 1
  page any hour, Sev 2 page any hour, Sev 3 channel next business day,
  Sev 4 ticket, marked proposed.
- People: the team table (README, CODEOWNERS teams, `.bearing/company.json`)
  with location, time zone, leave and departure dates. Unknown: ask once
  for names, zones and dates; otherwise `<rotation>` placeholders, counted.
- Paging tool: from config (`opsgenie_configs`, `pagerduty_configs`,
  `.env.example` keys), then the user, then prose. None: tool-neutral.
- ADRs and policies that constrain a freeze or a release (`docs/adr/`).
- `review`: a pasted export or `docs/postmortems/*.md` of the week; absent:
  "0 pages examined".
- Templates: `templates/on-call.md`, `templates/handover.md`,
  `templates/weekly-review.md`.

## Steps

1. `setup`: write `docs/operations/on-call.md` from `templates/on-call.md`,
   Status Proposed until the team agrees; name nobody as approver.
   - Rotation from who is available on the start date: drop anyone who
     leaves before it, and note anyone on leave during the first shifts
     with the dates. Give the load: with N people on weekly primary plus
     secondary, each person is on call 2 weeks in every N. Under four
     people is a burnout schedule and goes at the top with the fix
     (borrow from a named adjacent team, primary only until someone
     returns, or accept as a stated risk). Sustainable is about eight on
     one site, six per site on two.
   - Follow-the-sun only when each zone has at least three people;
     otherwise one person in a zone carries a solo weekly night shift. Give
     every handover time in each zone it touches, computed for the start
     date: EU clocks change on the last Sunday of October and March, US on
     the second Sunday of March and first of November, India never. Check
     with `date -d 'TZ="Europe/Lisbon" 2026-11-02 09:00'` (prints local time).
   - Escalation: primary acknowledges in 5 minutes, then secondary at 10,
     engineering lead at 20, service owner at 30. Roles beyond the rotation
     come from the repo or are `<placeholder>`; no invented phone numbers,
     emails or people.
   - Routing from the severity scale, then compare the Alertmanager tree
     with it (step 2's route walk) and list every divergence: a severity
     paging outside its allowed hours, a paging default receiver, a label
     value the tree does not match. Business-hours paging needs a
     `time_intervals` entry and `active_time_intervals` on the route
     (Alertmanager 0.24 or later; `location` needs 0.25), plus a
     `continue: true` copy to the channel so off-hours alerts still land
     somewhere visible.
   - Error budget from the SLO: a request-based SLO's budget is failed
     requests, (1 - target) x requests in the window; minutes,
     (1 - target) x 43,200 per 30 days, is only the full-outage equivalent
     (99.9 = 43.2 min, 99.95 = 21.6, 99.99 = 4.3). Give both when traffic
     is known.
   - Burn-rate check: each alert's threshold must be burn rate x
     (1 - target) for the target in slos.md. A constant left from an older
     target (0.001 against 99.95 percent) fires at a multiple of the
     intended rate; state the multiple and the corrected expression. Fast
     burn 14.4x over 1 h spends 2 percent of a 30-day budget and pages;
     slow burn 6x over 6 h spends 5 percent and is a ticket. Without a
     short confirming window (1/12 of the long one) the alert keeps firing
     long after recovery.
   - Budget policy agreed before it burns: 50 percent spent adds a
     reliability item; 100 percent restricts feature work on the service
     until the 30-day budget is positive again (or burn stays under 1x for
     7 days), lifted by the service owner in writing. Every exception an
     ADR requires (security fixes) is written into the freeze.
2. `check`: find the paging set from routing, then the runbook for each.
   - Route walk: for each loaded rule, take its labels through the tree
     (first matching child wins unless `continue`; no match falls to the
     root receiver; matchers are exact and case-sensitive). The alerts that
     reach a paging receiver are the paging set, whatever their severity
     label says. A missing severity label, or a value like `ticket` with no
     route, pages when the default receiver pages.
   - Run the gate over exactly the loaded files (files, not a directory,
     so an unloaded `.yml` is not counted):
     `bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-runbook-check" --paging <file> <file> ...`
     It checks label-paging rules (`page`, `critical`, sev 1 or 2) for a
     `runbook_url` that resolves and flags rules with no severity. Copy its
     counts lines. It cannot see routing, stubs or quality, so then:
   - For every alert in the paging set, open the runbook file. Missing
     means: no `runbook_url`; a link to a name that does not exist (compare
     with `ls docs/runbooks`: `HighLatency.md` is not `high-latency.md`;
     fix one side and leave one copy); or a stub (TODO, headings with empty
     bodies, template text). A usable runbook says how to confirm the alert,
     what to check and do, and when and to whom to escalate, using names
     from the repo (namespace, deployment, probe, the metrics in the
     `expr`). Facts the repo does not hold (a vendor status page, support
     line, dashboard URL, contact) are `<placeholder>`, never plausible
     prose.
   - Fix by writing the runbook, or by a deliberate reroute with the reason
     stated. Never reroute a Sev 1 (outage, data at risk) away from the
     pager to hide a missing runbook: write a minimal grounded runbook
     instead. Alert rules change in labels and annotations only; a wrong
     `expr` or threshold is reported with the proposed fix, or changed
     only with the change named in the final message.
   - Leave complete runbooks alone; correct a doc that claims full
     coverage. Run `promtool check rules` and `amtool check-config` when
     installed; otherwise say not run. Every YAML edited still parses.
3. `handover`: write `docs/operations/handover/<date>.md` from
   `templates/handover.md`: open incidents, silences with expiry, alerts
   that fired more than three times, changes this week (`git log
   --since='7 days ago' --format=%s`), risks next week, budget left. Ask
   once for what files cannot show; never invent a row.
4. `review`: write `docs/operations/reviews/<date>.md` from
   `templates/weekly-review.md`: pages by alert and hour, out-of-hours
   count, actionable against not, MTTA and MTTR, alerts to tune or delete,
   budget and the freeze decision. Print "N pages examined".
5. Report (contract below). Always list what the repo cannot do: the
   schedule, escalation policy and team in the paging tool; deploying or
   reloading changed rules and Alertmanager config (and by when, if the
   user named a date); tools not run.

## Output contract

```
## On-call: <repo> (<mode>)
People on <start date>: N (<names>); load: on call 2 weeks in N; under four: yes|no
Tool: <from config> (<stale prose, if any>)
Routing divergences: <severity.md vs alertmanager.yml, one per line | none>
Error budget: <target> = <failed requests>/30d (<minutes> full-outage); burn thresholds: ok | <found> vs <expected>
Rules: <T> in <F> loaded files (<unloaded files | none>); paging by route: <P>; runbooks missing: <names | none>
Runbook check: <brg-runbook-check counts lines, verbatim>
Not done: paging tool setup; deploy/reload of <files>; <tools not run>
Paths: <files written or changed>
```

## Gotchas

- Label names do not decide paging; the route tree does. The default
  receiver is where every unmatched and unlabelled alert goes.
- A runbook file that exists can still be missing: a stub, or a link whose
  case or spelling differs from the file.
- An alert in a file Prometheus does not load is dead, not safe.
- The budget of a request-based SLO is requests; quoting only minutes
  hides that a 2 percent error rate spends it 50 times slower than an
  outage.
- Burn-rate constants drift when the SLO target moves; recompute them from
  slos.md every time.
- A rotation is sized from the start date, not today's team table, and
  handover times are converted for that date's clocks.
- The freeze rule is worthless unless agreed before the budget burns, and
  it may not block what an ADR says must always ship.
- A silence without an expiry is a deleted alert. The handover lists every
  silence with its end time.
- MTTA counts from the alert firing, not from the acknowledgement.
