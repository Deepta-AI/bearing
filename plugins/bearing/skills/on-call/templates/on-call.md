# On-call: <service or team>

<!-- Template guidance: every section below carries a comment saying what goes
     there (What), what a strong entry has (Good) and a one-line example
     (Example). Delete each comment when you fill its section. This is the
     contract between the alerts and the people they page: who is on the
     hook, how a page climbs, what each severity does and what a burnt error
     budget costs the roadmap. Read by every engineer joining the rotation. -->

Owner: <rotation>   Paging tool: <name | none named>   Last reviewed: <YYYY-MM-DD>

Findings: <rotation under four people | none>

## Rotation

<!-- What: primary and secondary rotations, one-week shifts, a fixed handover
     weekday and hour, the time zone; follow-the-sun when the team spans two.
     Good: members are a rotation name and a headcount, never a person's
     name. A rotation under four people is a burnout schedule: say so on the
     Findings line at the top of the document, not in a footnote.
     Example: "| primary | 5 people: payments-oncall | 1 week | Monday 10:00 | Asia/Kolkata |" -->

| Rotation | Members | Shift | Handover | Time zone |
| --- | --- | --- | --- | --- |
| primary | <n> people: <rotation name> | 1 week | <weekday> <hour> | <tz> |
| secondary | <n> people: <rotation name> | 1 week | <weekday> <hour> | <tz> |


## Escalation

<!-- What: how an unacknowledged page climbs, step by step.
     Good: primary acknowledges in 5 minutes, secondary at 10, engineering
     lead at 20, service owner at 30. Each step names a rotation or a role,
     never a person, so the document survives people moving on. Sev 3 and 4
     never page.
     Example: "| 3 | engineering lead | 20 min | page |" -->

| Step | Who | After | How |
| --- | --- | --- | --- |
| 1 | primary | 0 min (acknowledge in 5) | page |
| 2 | secondary | 10 min unacknowledged | page |
| 3 | engineering lead | 20 min | page |
| 4 | service owner | 30 min | page and channel |

## Severity and routing

<!-- What: what each severity means, where it goes and how fast someone
     responds. Use docs/operations/severity.md when the repository has one.
     Good: Sev 1 and 2 page primary; Sev 3 goes to a named service channel
     for the next business day; Sev 4 is a ticket. Replace <channel> with a
     real channel. A paging alert without a runbook is routed to the channel
     until the runbook exists.
     Example: "| 3 | minor, workaround exists | #payments-alerts | next business day |" -->

| Sev | Meaning | Route | Response |
| --- | --- | --- | --- |
| 1 | users blocked or data at risk | page primary now | acknowledge in 5 min, incident declared (`incident`) |
| 2 | degraded for many users | page primary now | acknowledge in 5 min |
| 3 | minor, workaround exists | <channel> | next business day |
| 4 | cosmetic | ticket | backlog |

Every alert rule carries `severity` and, when it pages, `runbook_url`.

## SLO and error budget

<!-- What: one row per SLO from docs/observability/slos.md, with the budget
     per 30 days and the two burn-rate alerts.
     Good: the budget is computed from the target (99.9 percent over 30 days
     is 43 minutes); fast burn (14.4x over 1 h) pages, slow burn (6x over
     6 h) opens a ticket. Without slos.md the defaults stay "proposed" until
     the owner confirms them on a named date.
     Example: "Status: confirmed by the payments service owner on 2026-09-21" -->

| Service | SLO | Window | Budget | Fast burn (page) | Slow burn (ticket) |
| --- | --- | --- | --- | --- | --- |
| <service> | 99.9% availability | 30 d | 43 min | 14.4x over 1 h | 6x over 6 h |
| <service> | p95 < 300 ms reads, 800 ms writes | 30 d | 5% of requests | | |

Status: proposed | confirmed by <owner> on <date>

### Budget policy

<!-- What: what the roadmap gives up as the budget burns, agreed before it
     burns; nobody agrees to a freeze during one.
     Good: 50 percent consumed adds a reliability item; 100 percent freezes
     features on the service until the burn rate stays under 1x for 7 days;
     the service owner lifts it in writing. The policy counts only once the
     Status line above says confirmed.
     Example: "Freeze on checkout-api from 2026-09-18; lifted 2026-09-29 by the service owner." -->

- 50% consumed: the weekly review adds one reliability item to the next sprint.
- 100% consumed: feature freeze on the service. Only reliability, security and
  incident-driven changes merge until the burn rate stays under 1x for 7 days.
- The freeze is lifted by the service owner in the weekly review, in writing.

## Handover

<!-- What: where the shift-change note lives and who writes it.
     Good: the path and the handover weekday and hour from Rotation, so the
     outgoing engineer knows the deadline.
     Example: "Outgoing primary writes docs/operations/handover/2026-09-28.md by Monday 10:00 IST." -->

Written every shift change from `docs/operations/handover/<date>.md`
(`on-call handover`).

## Weekly review

<!-- What: the weekday of the review and what it decides.
     Good: a fixed weekday, the path of the review notes, and the decisions
     it owns: alerts to tune or delete, the reliability item at 50 percent
     and the freeze at 100 percent.
     Example: "Every Thursday from docs/operations/reviews/2026-09-24.md" -->

Every <weekday> from `docs/operations/reviews/<date>.md` (`on-call review`):
pages, actionable share, MTTA, MTTR, alerts to tune, budget, freeze decision.
