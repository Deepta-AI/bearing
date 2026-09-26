# Queue, cron or outbox

| Mechanism | Choose when | Reject when | Delivery | Needs |
| --- | --- | --- | --- | --- |
| Queue | work is triggered by an event, fans out, or must run soon and in parallel | the trigger is a database write that must not be lost (use outbox to feed the queue) | at least once; visibility timeout returns lost messages | a broker (SQS, RabbitMQ, Redis Streams) or a `SKIP LOCKED` table |
| Cron | work is periodic and the period is the unit (nightly report, hourly sweep) | the work is per-event and latency matters | once per period per leader; a missed tick is a gap, not a retry | a scheduler with a leader lock or a period-keyed idempotency check |
| Outbox | the job must exist if and only if a transaction committed (send the email when the order is saved) | there is no transactional store, or the event has no owning write | at least once via a relay that reads the outbox and enqueues or calls | an `outbox` table in the same database, a relay process, a sweeper |

Defaults: outbox to produce, queue to consume, cron only for time-driven
sweeps. A queue fed directly from a request handler loses the message
when the enqueue succeeds and the write rolls back, or the reverse.

## Numbers to start from

| Setting | Default | Why |
| --- | --- | --- |
| Max attempts | 5 | enough for a dependency blip, not enough to hide a bug |
| Backoff | base 2 s, cap 5 min, full jitter | spreads a stampede; caps the wait |
| Job timeout | p99 of the job times 3 | slow is not stuck |
| Visibility timeout | job timeout plus 30 s, extended every timeout/2 | no double delivery mid-job |
| Shutdown grace | job timeout, capped by the platform (Kubernetes `terminationGracePeriodSeconds`) | finish or redeliver, never cut silently |
| Dead-letter alert | any message | a dead letter is a bug or an outage |
| Oldest-age alert | 5 times the expected latency | depth alone lies under bursts |

## Stack notes

- Go: `river` (Postgres), `asynq` (Redis), or a `SKIP LOCKED` loop;
  `signal.NotifyContext` for shutdown.
- Python: `arq` or `dramatiq` for queues, `APScheduler` with a
  database job store for cron, `celery` when it is already there.
- Node: `pg-boss` (Postgres) or `BullMQ` (Redis); `process.on('SIGTERM')`
  plus `worker.close()`.
- Postgres outbox: `outbox(id, aggregate, event, payload, created_at,
  published_at)`; relay `SELECT ... WHERE published_at IS NULL FOR
  UPDATE SKIP LOCKED LIMIT 100`.
