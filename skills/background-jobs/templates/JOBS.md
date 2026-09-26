# Background jobs

<!-- Template guidance: every section below carries a comment saying what goes
     there (What), what a strong entry has (Good) and a one-line example
     (Example). Delete each comment when you fill its section. This is the
     contract for every background job, written before the code and read by
     the on-call engineer and by webhooks when it hands work off. The
     mechanism comes from the accepted ADR, never chosen here. -->

Mechanism: <queue / cron / outbox> (ADR <id>). Broker or store: <name>.
Worker entry: `<path>`. Shutdown grace: <s> s. Dashboard: <link or panel>.

## Registry

<!-- What: one row per job with its full contract: key, retention,
     attempts, backoff, timeouts, dead letter, rate, owner, runbook.
     Good: the key says what makes two deliveries the same job; an empty key
     cell is a stop, not a default. Backoff has a base, a cap and full
     jitter; visibility is above the timeout; key retention outlasts retries
     plus dead-letter replay; cron keys are `job:<name>:<period start>`.
     Example: "| send-invoice-email | outbox `invoice.issued` |
     `invoice:<id>:email` | 30 days | 5 | 2 s, cap 5 min, jitter | 20 s |
     60 s | `email.dlq` | 40/min | billing | `docs/runbooks/send-invoice-email-backlog.md` |" -->

| Job | Trigger | Idempotency key | Key retention | Max attempts | Backoff | Timeout | Visibility | Dead letter | Rate | Owner | Runbook |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| <name> | <event / cron expr / outbox event> | `<key shape>` | <days, above the DLQ replay window> | 5 | 2 s, cap 5 min, jitter | <s> | <s> | `<queue>.dlq` | <n/min> | <team> | `docs/runbooks/<job>-backlog.md` |

## Effects that must not happen twice

<!-- What: per job, the side effect a second run would repeat and the guard
     that stops it.
     Good: the guard is a claim before the effect (a unique insert or an
     equivalent conditional write), with `done` recorded in the same
     transaction as a database effect; "we check first" is a race, not a
     guard. Each row has a test that delivers the message twice.
     Example: "| charge-renewal | card charged | key `renewal:<sub>:<period>`
     claimed in `job_keys`; the payment call sends it as the idempotency key |" -->

| Job | Effect | Guard |
| --- | --- | --- |
| <name> | <email sent / charge made / file written> | <key claimed by a unique insert before the effect; a unique violation skips it; `done` recorded with the effect> |

## Metrics and alerts

<!-- What: the five job metrics, their labels and the alert on each.
     Good: every threshold is a number (seconds, a rate), not "high"; oldest
     age and dead letters above 0 always alert; each alert links to the
     runbook in the Registry row. If the repository exposes no metrics and
     nothing scrapes, give the SQL that reads each number from the job
     table and mark the rows as a follow-up; add no endpoint for them.
     Example: "| `jobs_oldest_age_seconds` | queue | > 300 for 5 min |" -->

| Metric | Labels | Alert |
| --- | --- | --- |
| `jobs_queue_depth` | queue | informational |
| `jobs_oldest_age_seconds` | queue | > <s> for 5 min |
| `jobs_failed_total` | queue, job | rate > <n>/min |
| `jobs_dead_letter_total` | queue | > 0 |
| `jobs_duration_seconds` | job | p99 > timeout / 2 |

## Replay and stop

<!-- What: the exact commands to replay one dead letter, stop the workers and
     drain workers for a deploy.
     Good: each is a command someone can paste at 3 am, tested once;
     replay reuses the original key so a done job is not repeated; a dead
     letter is replayed or archived with the reason, never purged.
     Example: "Replay one dead letter: `make jobs-replay QUEUE=email
     ID=01J9Z3K8`" -->

- Replay one dead letter: `<command>`
- Stop the workers: `<existing command: scale to zero, stop the timer>`
- Drain for deploy: `<command>`
