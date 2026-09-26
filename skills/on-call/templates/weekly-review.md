# On-call weekly review: week of <YYYY-MM-DD>

<!-- Template guidance: every section below carries a comment saying what goes
     there (What), what a strong entry has (Good) and a one-line example
     (Example). Delete each comment when you fill its section. The weekly
     review turns the week's pages into decisions: which alerts to tune or
     delete and what the error budget costs the roadmap. Read by the rotation
     and the service owner. With no page data it still runs and says
     "0 pages examined". -->

Attendees: <roles>   Pages examined: <N>   Source: <export | postmortems>

## Pages

<!-- What: every page of the week grouped by alert, from a pasted export or
     the week's docs/postmortems/*.md.
     Good: counts come from the source, never by hand; MTTA counts from the
     alert firing, not from the acknowledgement; the Totals line gives the
     actionable share as a percentage.
     Example row: "| CheckoutErrorBudgetBurnFast | 3 | 2 | 1 | 4 min | 38 min | yes |" -->

| Alert | Count | Out of hours | Actionable | MTTA | MTTR | Runbook used |
| --- | --- | --- | --- | --- | --- | --- |

Totals: <N> pages, <k> out of hours, <a> actionable (<p>%), MTTA <m> min, MTTR <m> min

## Tune or delete

<!-- What: every alert that fired three times or more with no action taken,
     and the decision on it.
     Good: one decision per row (delete, downgrade to Sev 3, raise the
     threshold to a stated number) with an owning rotation; out-of-hours
     pages that led to no action are decided first.
     Example row: "| QueueDepthHigh | 6 | none | raise threshold from 500 to 2,000 | platform-oncall |" -->

| Alert | Fired | Action taken | Decision | Owner |
| --- | --- | --- | --- | --- |
| <alert> | 3+ | none | delete | downgrade to Sev 3 | raise threshold | <rotation> |

## Error budget

<!-- What: budget consumed and burn rate per service, and the decision the
     policy in docs/operations/on-call.md requires.
     Good: 50 percent consumed means a reliability item added; 100 percent
     means freeze on; a freeze is lifted only after 7 days under 1x, by the
     service owner in writing.
     Example row: "| checkout-api | 99.9% | 62% | 1.3x | reliability item added |" -->

| Service | SLO | Consumed | Burn rate | Decision |
| --- | --- | --- | --- | --- |
| <service> | 99.9% | <p>% | <x> | none | reliability item added | freeze on | freeze lifted |

## Follow-ups

<!-- What: every action the review agreed, one row each.
     Good: an owning rotation or role, a ticket id and a due date; an item
     without a ticket is not a follow-up.
     Example row: "| Delete QueueDepthHigh and its silence | platform-oncall | OPS-PP-077 | 2026-10-01 |" -->

| Item | Owner | Ticket | Due |
| --- | --- | --- | --- |
