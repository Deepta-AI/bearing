---
name: background-jobs
description: 'Builds background jobs that survive failure: queue, cron or outbox, idempotency keys, backoff retries, dead letters, graceful shutdown. Use when asked for a "background job", "queue", "cron job", "worker" or "outbox".'
argument-hint: "<job name or purpose> [--mechanism queue|cron|outbox] [--audit]"
allowed-tools: Read, Write, Edit, Grep, Glob, Skill, Bash(ls:*), Bash(mkdir -p:*), Bash(make check:*), Bash(make test:*), Bash(git diff:*), Bash(git status:*), Bash(go test:*), Bash(pnpm exec vitest:*), Bash(uv run pytest:*)
---

# background-jobs

Every job runs at least once, which means some run twice. The design
starts from that fact: an idempotency key, a bounded retry, a place for
the poison, a way to stop a worker without losing the message, and a
number on a dashboard that says how far behind we are.

Not this: `runbook` writes the full runbook for an alert once one
fires; this skill leaves the stub. `analytics-events` is analytics, not jobs.

## Inputs

- Job: `$1`, a name or a sentence; if absent, `--audit` over every job
  found; neither: one question: "what work, triggered by what, how
  often, and what happens if it runs twice?".
- Mechanism: `--mechanism`; else an accepted ADR under `docs/adr/`; else
  the `tech-decision` protocol with `references/mechanisms.md` in step 2.
- Existing jobs: grep for `cron`, `@scheduled`, `Every(`, `setInterval`,
  `celery`, `arq`, `dramatiq`, `river`, `asynq`, `BullMQ`, `pg-boss`,
  `SKIP LOCKED`, `Worker(`; zero hits is a valid answer for a new job.
  Also grep for claim, lock and idempotency helpers (`claim`,
  `job_claims`, `idempotency`, `advisory_lock`, `SETNX`) and list them:
  a new job reuses them.
- Store and broker: `compose.yaml` services and the config loader; if
  absent, Postgres is assumed (an outbox or `SKIP LOCKED` queue needs
  nothing else) and the report says so.
- Metrics module: `observability` output under `internal/telemetry/`,
  `app/telemetry/` or `src/telemetry/`, and whatever the deploy config
  scrapes. If the repository exposes no metrics and nothing scrapes, add
  no endpoint, server or alert file nobody loads: give the query that
  reads depth, oldest age and dead letters from the job table, and name
  the metrics as a follow-up in the report.
- Templates: `templates/JOBS.md` and `templates/job-runbook.md`, written
  where the repository keeps operational docs (`docs/operations/JOBS.md`,
  `docs/runbooks/<job>-backlog.md`). A repository with no docs directory
  gets a jobs section in its README instead of a new docs tree.

## Steps

1. Inventory: grep as in Inputs; print "jobs found: N" with trigger and
   file per job. With `--audit`, run steps 3 and 6 per job and stop;
   N=0 under `--audit`: stop with "0 jobs found; nothing to audit".
2. Mechanism, unless decided: read `references/mechanisms.md`, present
   the three with the recommendation and the reasons for this job (is
   it triggered by a write? by time? does it fan out?), one question,
   through `tech-decision`: an ADR only when the user answers; otherwise
   build behind the recommendation, write no ADR, and name the choice
   under "Decisions needed" in the final report only, never in a
   repository file (no "Decisions" or "Proposed" section in JOBS.md).
3. Contract per job, written before code, into the jobs doc (Inputs):
   idempotency key (what makes two deliveries the same job), max
   attempts, backoff (base, cap, full jitter), job timeout, visibility
   timeout (greater than the job timeout), dead-letter destination and
   who reads it, expected rate, the effect that must not happen twice,
   and key retention, longer than the longest path that can redeliver
   the job (retries plus dead-letter replay). A row with an empty
   idempotency key is a stop.
4. Implement in the stack's shape:
   - Producer: enqueue in the same transaction as the write it follows
     (outbox) or with the key set (queue); cron entries are idempotent
     by period (`job:<name>:<period start>`).
   - Handler: claim through the claim table or helper the repository
     already has (Inputs); a second claim table or lock beside an
     existing one is a finding to report, not a design. With none,
     claim the key atomically before the side effect, an
     insert into a table with a unique constraint on the key (state
     `in_progress`) or an equivalent conditional write, in the same
     transaction as the effect when the effect is a database write. A
     unique violation means already done or in progress: acknowledge a
     done key, back off on an in-progress one, never run the effect.
     Mark the key `done` with the effect in one transaction; raise a
     typed `Retryable` or `Poison` error; never catch and swallow.
     `Retryable` is an allowlist: only errors known to be transient and
     safe to repeat (a timeout on a call that carries the idempotency
     key, a 429, a 503). A decline, a validation error and any error of
     unknown kind are `Poison` until someone classifies them; "retry
     everything else" is the bug, not the default. A
     read of the key followed by the effect is a race, not a claim.
   - Worker: `SIGTERM` stops taking work, finishes in-flight jobs inside
     the grace period, extends the visibility timeout while a job runs,
     and exits non-zero when a job is cut off so it is redelivered.
   - Poison: after max attempts the job moves to the dead letter with
     the last error and attempt count; a dead letter is never dropped.
   - Metrics: `jobs_queue_depth{queue}`, `jobs_oldest_age_seconds{queue}`,
     `jobs_failed_total{queue,job}`, `jobs_dead_letter_total{queue}`,
     `jobs_duration_seconds{job}`; alerts on oldest age and dead letters.
     Only through a metrics surface the repository already has (Inputs);
     otherwise the query and the follow-up, not a new endpoint.
   - Scope: build what the request needs plus the replay path for a dead
     letter. No pause switch, admin route or dashboard nobody asked for;
     the runbook names the existing way to stop work (scale the worker
     to zero, stop the timer) instead of inventing one.
5. Tests, one per property, run and counted: the same message twice
   yields one effect; the same message delivered to two workers at
   once yields one effect (both run concurrently, one claim wins, the
   other sees the unique violation); a `Retryable` error retries with growing delay
   and succeeds; a `Poison` error dead-letters after max attempts;
   `SIGTERM` mid-job redelivers it; a cron tick that overlaps the
   previous run does not run twice. Print "job tests: N passed".
6. Runbook stub from `templates/job-runbook.md` per job: what the
   backlog alert means, how to read the dead letter, how to replay one
   message, how to stop the workers with what already exists. Print the
   contract.

## Output contract

```
## Jobs: <job | audit> (<queue | cron | outbox>, ADR <id> | audited)
Jobs found: N   Contracts written: N (idempotency key set: N of N)
| Job | Trigger | Key | Attempts | Backoff | Timeout / visibility | DLQ |
...
Worker: shutdown grace <s> s, visibility extension <yes|no>
Metrics: N registered   Alerts: oldest age > <s>, dead letters > 0
Tests: N passed   Docs: <jobs doc>, <runbook>
Not done: <list> | none
```

## Gotchas

- When the request reports an incident (a double charge, a lost
  email), name as its cause only what you reproduced against the code,
  a test that fails before the fix, or what the user said. Other
  hazards you found and fixed are "also possible", not "the cause";
  check that the code path ran at all before blaming it.

- "Exactly once" is a marketing term. Design for at least once and make
  the effect idempotent; the key is the design, not the broker setting.
- "Check the key, then act" lets two workers both see "not seen" and
  both act. The unique constraint picks the winner; a store that cannot
  enforce uniqueness in one operation cannot back the claim.
- A key retained for less time than the dead letter is kept turns a
  replay a week later into a second effect.
- A retry without jitter turns one outage into a synchronised stampede
  when the dependency comes back. Full jitter, always.
- A visibility timeout shorter than the job timeout hands the same job
  to two workers. Extend it while working or set it above the timeout.
- Cron on two replicas runs twice. The period key or a leader lock is
  the fix; hoping only one pod schedules is not.
- Catching every exception to keep the worker alive turns poison into a
  hot loop. Classify the error and let the runtime count attempts.
- Draining the dead letter by deleting it loses the only record of what
  failed. Replay or archive with the reason; never `PURGE`.
- The outbox table needs a sweeper and a retention window, or it is the
  slowest growing table in the database.
