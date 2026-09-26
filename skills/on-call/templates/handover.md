# On-call handover: <YYYY-MM-DD>

<!-- Template guidance: every section below carries a comment saying what goes
     there (What), what a strong entry has (Good) and a one-line example
     (Example). Delete each comment when you fill its section. Written by the
     outgoing engineer at every shift change and read by the incoming one
     before their first page. Ask once for what files cannot show (silences,
     budget); never invent a row. An empty table says "none". -->

From: <outgoing rotation slot>   To: <incoming rotation slot>   Service(s): <list>

## Open incidents

<!-- What: every incident still open at the handover, one row each.
     Good: the id links to the incident or postmortem doc; the next step is
     one concrete action with its owner, not "monitoring".
     Example row: "| INC-231 | 2 | 2026-09-26 14:10 UTC | mitigated | confirm refund backlog drains below 50, secondary | docs/incidents/INC-231.md |" -->

| Id | Sev | Since | Status | Next step | Doc |
| --- | --- | --- | --- | --- | --- |

## Silences

<!-- What: every active alert silence.
     Good: each one has an expiry in UTC and a reason; a silence without an
     expiry is a deleted alert, so set one before handing over.
     Example row: "| PaymentsLatencyP95High | provider maintenance window | 2026-09-29 06:00 | primary |" -->

| Alert | Reason | Expires (UTC) | Set by |
| --- | --- | --- | --- |

## Noisy alerts this week (fired more than three times)

<!-- What: alerts that fired more than three times this shift.
     Good: counts come from the paging tool or its export, not memory;
     "Actionable" says how many fires led to an action; the proposed change
     is specific (delete, downgrade to Sev 3, raise the threshold to a number).
     Example row: "| DiskUsageHigh | 7 | 0 | raise threshold from 80% to 90% |" -->

| Alert | Fired | Actionable | Proposed change |
| --- | --- | --- | --- |

## Changes deployed this week

<!-- What: what shipped during the shift, from
     `git log --since='7 days ago' --format=%s`.
     Good: each row names its ticket and how to roll it back (a revert, a
     flag, a migration down), so the incoming engineer can undo it at 3am.
     Example row: "| 2026-09-25 | Move receipts to the async queue | PAY-PP-142 | flag receipts_async off |" -->

| Date | Change | Ticket | Rollback |
| --- | --- | --- | --- |

## Risks next week

<!-- What: known events that may page next shift.
     Good: each risk has a date and what to watch; "none" is a valid answer.
     Example: "- 2026-10-01 18:00 IST: Postgres 15 to 16 upgrade on orders-db; watch replication lag." -->

- <planned migration, launch, dependency change, holiday cover>

## Error budget

<!-- What: budget left per service at the handover.
     Good: the percentage and the 24 h burn rate come from the budget panel
     or the engineer, never estimated; Freeze says on or off per the policy
     in docs/operations/on-call.md.
     Example row: "| checkout-api | 38% | 1.6x | off |" -->

| Service | Budget left | Burn rate (24 h) | Freeze |
| --- | --- | --- | --- |

## Notes for the incoming engineer

<!-- What: anything that is not in a file: a flaky dependency, a pending
     vendor reply, a customer watching closely.
     Good: each note says what to do about it, not only that it exists.
     Example: "- The SMS provider ticket 88213 is open; if OTP failures pass 2%, switch to the backup sender flag." -->

- <anything that is not in a file>
