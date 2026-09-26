# Webhook test scenarios (<provider or outbound>)

<!-- Template guidance: the cases every webhook needs, as scenarios, not as
     a table. When the repository already keeps a test-case table
     (docs/testing/test-cases.md), webhooks adds each scenario it keeps
     as a row there, in that table's own columns and with the next free
     TC-nnnn id; when it keeps none, the tests are the record and no table
     is created.
     Keep, adapt or drop each scenario and add provider-specific ones.
     Delete each comment when you fill its section. -->

## Inbound

<!-- What: the receiving side: signature, freshness, duplicates, and the
     handler acking before the work runs.
     Good: every Then is observable (a status code, a row count, a job
     count, a header), never "works"; each kept scenario becomes one row
     with Title "Webhook: <scenario>", Type integration, and P1 for
     signature and duplicate cases.
     Example: "Webhook: payload over 1 MiB. Given a 1.2 MiB body, when the
     provider posts it, then 413, no webhook_events row, no job." -->

- Valid signature: given a valid signature and a fresh timestamp, when the
  provider posts an event, then 200 within 1 s, one `webhook_events` row,
  one job enqueued.
- Wrong signature: given a wrong signature, when the provider posts, then
  401, no row, no job, and the body carries no detail.
- Stale timestamp: given a signature over a timestamp older than 5 minutes,
  when the provider posts, then 401 and no row.
- Duplicate event: given an event id already stored, when the provider posts
  it again, then 200, no new row, no new job.
- Handler failure: given the job handler raises, when the provider posts,
  then 200 was already returned and the job retries per JOBS.md.
- Secret rotation: given a rotation in progress, when the provider signs
  with the previous secret, then 200.

## Outbound

<!-- What: the sending side: retries, rejection, the consumer's delivery log,
     rate limits, secret rotation and replay.
     Good: the retry schedule and the dead-letter point are stated in time,
     and a replay keeps the event id (X-Webhook-Id) so consumers dedupe.
     Example: "Webhook: consumer 500. Given the endpoint returns 500, when an
     event fires, then attempts at 0 s, 1 min, 5 min, 30 min, 2 h, 12 h,
     24 h, then dead letter." -->

- Consumer 500: given the endpoint returns 500, when an event fires, then
  attempts at 0 s, 1 min, 5 min, 30 min, 2 h, 12 h, 24 h, then dead letter.
- Consumer 400: given the endpoint returns 400, when an event fires, then
  one attempt, no retry, logged as rejected.
- Delivery log: given any delivery, when the consumer opens their log, then
  every attempt shows its status code, duration and next attempt time.
- Hanging consumer: given consumer A's endpoint never answers and consumer
  B's answers 200, when one event is due for each, then B receives its
  event well inside the client timeout, without waiting on A.
- Rate limit: given a consumer at its limit, when ten events fire at once,
  then deliveries are spaced to the limit and none is dropped.
- New secret: given a new secret issued, during the next 24 h both
  signatures are present; after 24 h only the new one.
- Replay: given a dead-lettered delivery, when the consumer replays it, then
  one new attempt with the same event id, linked to the original delivery.
