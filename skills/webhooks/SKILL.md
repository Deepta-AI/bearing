---
name: webhooks
description: 'Builds webhooks both ways: inbound with signature checks, replay window and idempotent handlers; outbound with retries, dead letters and a delivery log. Use when asked to "add a webhook" or "verify signatures".'
argument-hint: "inbound <provider> | outbound <event ...> | audit"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(ls:*), Bash(mkdir -p:*), Bash(make check:*), Bash(make test:*), Bash(git diff:*), Bash(git status:*), Bash(go test:*), Bash(pnpm exec vitest:*), Bash(uv run pytest:*)
---

# webhooks

A webhook is a request from a stranger that must be believed, and a
request to a stranger that must be proven. Inbound, the handler
verifies before it parses and acks before it works. Outbound, the
sender keeps a log the consumer can read, because "did you send it" is
the first question every integration asks.

Not this: `background-jobs` builds the worker the inbound handler hands off
to; `analytics-events` is product analytics; `openapi-spec` is the request
and response API, not events.

## Inputs

- Mode: `$1`; if absent, `audit` over what exists; `audit` with
  nothing found stops with "0 webhook handlers or senders found".
- Provider for `inbound`: `$2`; its signature scheme from the provider's
  docs when the engineer pastes the relevant lines, else the common
  shape (HMAC-SHA256 over `timestamp.body`, header carries `t=` and
  `v1=`) with a note "scheme: assumed, confirm against provider docs".
- Events for `outbound`: `$2..`; if absent, the domain events in
  `docs/design/*-hld.md` or the outbox table; if none, one question.
- Job mechanism for the async half: `docs/operations/JOBS.md`; if
  absent, an in-process queue with the note that `background-jobs` hardens it.
- Secret: the name only, from `docs/security/SECRETS.md` or the env
  read; the value never appears.
- Docs: the repository's own document for this integration when one
  exists (for example `docs/integrations/<provider>*.md` or a partner
  guide); update it in place. `templates/WEBHOOKS.md` becomes
  `docs/integrations/WEBHOOKS.md` only when nothing covers the
  integration yet; never a second document beside an existing one.
- Test scenarios: `templates/webhook-test-cases.md` is a checklist for
  choosing tests. When the repository already keeps a test-case table
  (`docs/testing/test-cases.md`), each scenario kept becomes a row there
  in that table's own columns with the next free `TC-nnnn` id; when it
  does not, the tests themselves are the record and no table is created.

## Steps

1. Inventory: grep for `webhook`, `X-Signature`, `X-Hub-Signature`,
   `Stripe-Signature`, `hmac`, `verify_signature`, `deliveries`. Print
   "handlers: N, senders: M". With `audit`, check each against the
   inbound and outbound lists below and report; nothing is changed.
2. `inbound <provider>`:
   - Read the raw body bytes before any JSON parse; compute HMAC over
     exactly what the provider signed; compare with the language's
     constant-time function (`hmac.Equal`, `hmac.compare_digest`,
     `crypto.timingSafeEqual`); reject with 401 on mismatch, missing
     header or malformed header, no detail in the body.
   - Replay window: reject a timestamp older than 5 minutes; require
     the timestamp inside the signed payload.
   - Idempotency: `webhook_events(provider, event_id, received_at,
     processed_at, status)` with a unique key on `(provider, event_id)`;
     the insert is the claim, and a unique violation returns 200
     without work. Keep rows longer than the provider's retry window
     plus any manual resend, never a fixed 24 h.
   - Fast ack: insert the row, enqueue the job, return 2xx inside 1 s;
     all processing in the job. A 5xx makes the provider retry; a 4xx
     makes it stop; choose deliberately. Once the handler has acked, the
     provider will not send the event again, so the job owns the retry:
     a processing failure retries with backoff up to a max attempts and
     then dead-letters (`background-jobs` contract); recording `failed` and
     returning loses the event.
   - Dual secret during rotation: verify against current and previous
     for the rotation window.
3. `outbound <events>`:
   - Catalogue every event: name (`<domain>.<noun>.<verb>`), payload
     schema, version, when it fires, sample. Print "events: N".
   - Signing: `X-Webhook-Id`, `X-Webhook-Timestamp`, `X-Webhook-Signature:
     v1=<hmac-sha256(secret, id.timestamp.body)>`, one secret per consumer.
     `X-Webhook-Id` is the event id, the same on every attempt and every
     replay, so the consumer can dedupe on it; never the delivery id.
   - Delivery: attempts at 0 s, 1 min, 5 min, 30 min, 2 h, 12 h, 24 h;
     success is any 2xx inside 10 s; after the last attempt the delivery
     is dead-lettered and the consumer's endpoint is marked failing.
   - Delivery log table `webhook_deliveries(id, consumer, event_id,
     attempt, status_code, duration_ms, next_at, last_error)` and an
     endpoint (or page) where a consumer sees their own log and can
     replay by id.
   - Isolation: one consumer's slow or dead endpoint never delays
     another's deliveries. Deliver per consumer (a worker per consumer,
     or bounded concurrency with at most one in flight per consumer),
     never one serial loop over every due delivery, where each hanging
     endpoint makes everything behind it wait out the full timeout. The
     circuit breaker does not solve this: it trips only after many
     timeouts have already been waited out.
   - Per-consumer rate limit (token bucket, default 10 per second) and a
     circuit breaker that pauses a consumer after 100 consecutive fails.
   - Secret rotation endpoint: issue a new secret, sign with both for
     24 h, then drop the old.
4. Tests from the scenarios in `templates/webhook-test-cases.md` (rows
   in the test-case table only when the repository keeps one, as under
   Inputs), each written as a test named after its scenario:
   valid signature accepted; wrong signature 401; stale timestamp 401;
   duplicate event id acked once and processed once; handler acks
   before the job runs; a job that fails once then succeeds processes
   the event; a job that keeps failing dead-letters; outbound retries follow the schedule; dead
   letter after the last attempt; consumer log shows every attempt;
   rate limit holds; one consumer's endpoint hangs while another still
   receives its event well inside the client timeout. Run; print
   "webhook tests: N passed".
5. Update the integration document chosen under Inputs and print the
   contract.

## Output contract

```
## Webhooks: <inbound <provider> | outbound | audit>
Handlers: N   Senders: M   Events catalogued: E
Inbound: verify <constant-time fn>, replay window 5 min, idempotent on (provider, event_id), ack < 1 s, dual secret <yes|no>
Outbound: schedule 0/1m/5m/30m/2h/12h/24h, dead letter after 7, log table <name>, replay <endpoint>, rate <n>/s per consumer
Secret: <NAME> (rotation window 24 h)
Tests: N passed   Docs: <the integration document updated or created>
Not done: <list> | none
```

## Gotchas

- Parsing the JSON and re-serialising it before signing changes the
  bytes. Sign and verify the raw body, always.
- `==` on two hex strings leaks the position of the first wrong byte.
  Constant-time compare or the check is decorative.
- A handler that does the work before the 200 times out on the
  provider's side and gets the same event again, now twice as slow.
- Idempotency keyed on the payload hash breaks when the provider
  resends with a new timestamp. Key on the provider's event id.
- Outbound retries with no cap and no dead letter hammer a consumer
  that is down for a day, then flood them when they return.
- A consumer who cannot see their delivery log will open a ticket for
  every missed event. The log is the support tool.
- Retrying on 4xx punishes a consumer who rejected a malformed event;
  retry on 5xx, timeouts and connection errors only.
- A serial delivery loop turns one consumer's outage into everyone's
  outage: with a 10 s timeout and 50 due deliveries to a hanging
  endpoint, every other consumer waits over 8 minutes.
- A second webhook document beside the one the repository already has
  splits the truth in two; the next reader updates one and not the
  other.
