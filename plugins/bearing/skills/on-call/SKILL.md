---
name: on-call
description: 'Sets up on-call: rotation, escalation, alert routing by severity, error budget policy, handover notes, a runbook for every paging alert. Use when asked about "on-call", "who gets paged", "escalation" or "error budget".'
argument-hint: "[setup|check|handover|review] [--service <name>]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(ls:*), Bash(mkdir -p:*), Bash(date:*), Bash(promtool check:*), Bash(git log:*), Bash(bash *bin/brg-runbook-check*)
---

# on-call

A pager is a contract between the alert and a person. This skill writes
who is on the hook, how a page climbs, what each severity does, what a
burnt error budget costs the roadmap, and refuses to let an alert page
without a runbook.

Not this: `observability` writes the alert rules; `runbook`
writes one runbook; `incident` runs a live incident.

## Inputs

- alert rules: `monitoring/alerts/*.yaml` and any Prometheus rule file
  found by `Glob` on `*alert*.y*ml`; if absent, `check` fails (the
  runbook gate prints "0 rule files read, nothing checked") and `setup`
  writes an empty routing table.
- runbooks: `docs/runbooks/*.md`; absent: every paging alert is missing one.
- SLOs: `docs/observability/slos.md`; if absent, defaults proposed
  (availability 99.9 percent, p95 300 ms reads and 800 ms writes) and
  marked `proposed`.
- rotation members: `CODEOWNERS` teams, `.bearing/company.json` contacts; if
  absent, ask once for the rotation names and their headcount; unknown:
  `<rotation>` placeholders, counted.
- paging tool: named by the user, or found in CI, compose or `.env.example`
  (`pagerduty`, `opsgenie`, `grafana-oncall`); if absent, the routing
  table is tool-neutral and names channels only.
- severity scale: `docs/operations/severity.md` when present; else Sev 1
  (users blocked, page now), Sev 2 (degraded, page now), Sev 3 (minor,
  business hours), Sev 4 (cosmetic, ticket).
- pages for `review`: a pasted export or `docs/postmortems/*.md` of the
  week; if absent, the review says "0 pages examined" and still runs.
- templates in this skill: `templates/on-call.md`, `templates/handover.md`,
  `templates/weekly-review.md`.

## Steps

1. `setup`: write `docs/operations/on-call.md` from `templates/on-call.md`.
   Rotation: primary and secondary, one-week shifts, handover on a fixed
   weekday and hour, follow-the-sun when the team spans two time zones.
   Fewer than four people in a rotation is written as a finding.
   Escalation: primary acknowledges in 5 minutes, secondary at 10,
   engineering lead at 20, service owner at 30; Sev 3 and 4 never page.
   Routing: Sev 1 and 2 page primary; Sev 3 to the service channel next
   business day; Sev 4 a ticket. Error budget: minutes per 30 days from
   the SLO (99.9 = 43 min); fast burn (14.4x over 1 h) pages, slow burn
   (6x over 6 h) opens a ticket; at 50 percent consumed the weekly
   review adds a reliability item; at 100 percent a feature freeze on
   the service: only reliability changes merge until the burn rate stays
   under 1x for 7 days. Print placeholders left.
2. `check`: run the runbook gate in paging mode over the rule files
   found in Inputs:
   `bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-runbook-check" --paging monitoring/alerts`
   (add any other rule file `Glob` found as a further argument). It
   counts the rules from the files: every rule with a paging severity
   (`page`, `critical`, sev 1 or 2) needs a `runbook_url` that resolves
   to a file under `docs/runbooks/`, and every rule needs a `severity`
   label (without one it is unroutable). It prints a `problem:` line
   with the `runbook <Alert>` command per missing runbook and exits
   1 on zero paging alerts, any missing runbook or any unroutable rule.
   Copy its two counts lines; never count by hand. `promtool check
   rules` when installed.
3. `handover`: write `docs/operations/handover/<date>.md` from
   `templates/handover.md`: open incidents, silences with expiry, alerts
   that fired more than three times, changes deployed this week (`git
   log --since='7 days ago' --format=%s`), risks next week, budget left
   per service. Ask once for what files cannot show (silences, budget);
   never invent a row.
4. `review`: write `docs/operations/reviews/<date>.md` from
   `templates/weekly-review.md`: pages by alert and by hour, out-of-hours
   count, actionable against not, MTTA and MTTR, alerts to tune or
   delete (fired three times with no action taken), budget status and
   the freeze decision. Print "N pages examined".
5. Print the contract.

## Output contract

```
## On-call: <repo> (<mode>)
Rotations: N (<k> people each; under four: <names | none>)   Tool: <name | neutral>
Escalation: ack 5 min -> secondary 10 -> lead 20 -> owner 30
Routing: Sev1 page, Sev2 page, Sev3 <channel>, Sev4 ticket
Error budget: <SLO> = <minutes>/30d; freeze at 100% (proposed | confirmed)
Runbook check: <brg-runbook-check --paging counts lines, verbatim> (runbook <Alert> ...)
Pages examined: N (review)   Placeholders: P
Paths: docs/operations/on-call.md [, handover/<date>.md, reviews/<date>.md]
```

## Gotchas

- A paging alert without a runbook may not page. The check fails, and
  the rule is routed to the channel until the runbook exists.
- Escalation names rotations and roles, never a person. People rotate;
  the document does not change when they do.
- A rotation under four people is a burnout schedule; the document says
  so at the top, not in a footnote.
- The freeze rule is worthless unless agreed before the budget burns;
  nobody agrees to a freeze during one.
- A silence without an expiry is a deleted alert. The handover lists
  every silence with its end time.
- Out-of-hours pages that led to no action are the first thing the
  weekly review downgrades or deletes.
- MTTA counts from the alert firing, not from the acknowledgement.
