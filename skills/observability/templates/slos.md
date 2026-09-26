# Service level objectives: __SERVICE__

<!-- Template guidance: every section below carries a comment saying what goes
     there (What), what a strong entry has (Good) and a one-line example
     (Example). Delete each comment when you fill its section. This document
     says what "working" means for the service, which signal answers each
     on-call question, and the targets the dashboard and burn-rate alerts
     enforce. Read by on-call and the lead. The first two sections are
     written before any instrumentation; the rest is completed later and
     never rewritten. Numbers are proposals until the lead confirms them. -->

Status: proposed | confirmed by <lead> on <date>
Window: rolling 30 days. Source: `http_server_request_duration_seconds`
from the OpenTelemetry HTTP instrumentation, scraped through the
collector. Dashboard: `monitoring/dashboards/__SERVICE__-red.json`.

## What working means

<!-- What: one or two sentences per user journey the service carries: what
     a user does, and what they see when it works. Written before any
     instrumentation.
     Good: observable from outside with a number in it (a time, a count);
     when the code and the event sheet do not name the journeys, ask the
     engineer rather than guess.
     Example: "A paid order is confirmed within 2 s and the receipt email leaves within a minute." -->

## Questions on-call will ask

<!-- What: two to four questions on-call will ask, each answered by a named
     signal and the panel or query that shows it.
     Good: every span, counter and alert added later answers one of these;
     a signal that answers none is not added, and a question no signal
     answers stays open here as a gap.
     Example row: "| 3 | are refunds stuck in the queue? | refunds_pending gauge | RED dashboard: refunds |" -->

| # | Question | Signal (metric, span or log field) | Panel or query |
| --- | --- | --- | --- |
| 1 | <is the checkout failing, and for whom?> | <http_server_request_duration_seconds by http_route, status> | <RED dashboard: errors> |
| 2 | <is the payment provider slower than usual?> | <client span duration, peer.service> | <Tempo search> |

## Objectives

<!-- What: each SLI as a ratio of good events to all events, its target and
     the budget that target leaves per 30 days.
     Good: the definition names the metric and labels it counts; defaults
     are 99.9 percent availability and p95 under 300 ms reads and 800 ms
     writes, marked proposed until the lead confirms; exclusions are listed.
     Example row: "| Availability | non-5xx responses / all responses | 99.95 % | 22 min of full outage |" -->

| SLI | Definition | Target | Budget per 30 days |
| --- | --- | --- | --- |
| Availability | non-5xx responses / all responses | 99.9 % | 43 min of full outage, or 0.1 % of requests |
| Latency (reads) | GET responses under 300 ms / all GET responses | 99 % | 1 % of reads may be slower |
| Latency (writes) | non-GET responses under 800 ms / all non-GET | 99 % | 1 % of writes may be slower |

Excluded from the SLI: `/healthz`, `/readyz`, `/metrics`, and 4xx
responses (a client error is not a service failure). Requests rejected
by rate limiting (429) are excluded and tracked separately.

## Error budget policy

<!-- What: a link to the one budget policy for this service, not a second
     policy. The policy (what the roadmap gives up as the budget burns, and
     who lifts a freeze) lives in docs/operations/on-call.md, written by
     on-call, so a repository never carries two freeze rules.
     Good: the link resolves and the policy there is marked confirmed; when
     there is no on-call document yet, say so and name on-call as the
     next step instead of writing thresholds here.
     Example: "Policy: docs/operations/on-call.md#budget-policy (confirmed by
     the checkout-api owner on 2026-09-21)." -->

Policy: docs/operations/on-call.md#budget-policy

## Burn-rate alerts

<!-- What: the multi-window burn-rate rules, matching
     monitoring/alerts/__SERVICE__.yaml row for row.
     Good: every rule has a runbook_url that resolves under docs/runbooks/
     (brg-runbook-check passes); fast burn pages, slow burn opens a ticket.
     Example row: "| ErrorBudgetBurnFast | 14.4x | 1 h | 5 m | 2 days | page |" -->

Two windows each, so a short spike does not page and a slow leak does
not hide. Rules in `monitoring/alerts/__SERVICE__.yaml`.

| Alert | Burn rate | Long window | Short window | Budget gone in | Severity |
| --- | --- | --- | --- | --- | --- |
| ErrorBudgetBurnFast | 14.4x | 1 h | 5 m | 2 days | page |
| ErrorBudgetBurnSlow | 6x | 6 h | 30 m | 5 days | ticket |

A burn rate of 1x means the budget lasts exactly the window. 14.4x over
one hour consumes 2 % of the monthly budget in that hour.

## Alert test fires

<!-- What: one row per alert, recording the one time it was fired on purpose.
     Good: the date, the channel it reached and whether the runbook link
     opened; an alert never fired stays "not fired" and is not reported as
     working.
     Example row: "| ErrorBudgetBurnFast | 2026-09-22 staging | #payments-oncall | yes | platform lead |" -->

Each alert is fired once before it counts: the threshold is lowered for
one evaluation (or `amtool alert add` in staging), and the page reaches
the right channel with a runbook link that opens.

| Alert | Fired on | Reached | Runbook link opened | By |
| --- | --- | --- | --- | --- |
| ErrorBudgetBurnFast | not fired | | | |
| ErrorBudgetBurnSlow | not fired | | | |
| LatencyP95High | not fired | | | |

## Latency alerts

<!-- What: symptom alerts on latency that are not SLO burn alerts.
     Good: the threshold, the duration and the rule name as written in the
     rules file, and where the latency SLO is reviewed instead.
     Example: "LatencyP95High pages when p95 on POST /orders stays above 800 ms for 10 minutes." -->

`LatencyP95High` pages when p95 stays above 800 ms for 10 minutes. It
is a symptom alert, not an SLO alert; the latency SLO is reviewed
weekly from the dashboard.

## Review

<!-- What: when the targets are read against real traffic and by whom.
     Good: a target never breached in three months is tightened or
     dropped; one breached every month is resourced or loosened; the
     decision goes in the change log below.
     Example: "Monthly, first Monday: the lead re-reads targets against the 30-day panel." -->

- Weekly: the on-call reads the budget panel and notes the number in
  the team channel.
- Monthly: targets are re-read against real traffic. A target no one
  has breached in three months is tightened or dropped; a target
  breached every month is either resourced or loosened, with the
  decision recorded here.

## Change log

<!-- What: every change to a target, a window or the policy, newest last.
     Good: a date, what changed from what to what, and who decided.
     Example row: "| 2026-10-06 | Read latency target 300 ms to 250 ms after three clean months | platform lead |" -->

| Date | Change | By |
| --- | --- | --- |
| <date> | Initial targets proposed by observability | <name> |
