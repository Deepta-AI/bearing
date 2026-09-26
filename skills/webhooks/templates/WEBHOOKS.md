# Webhooks

<!-- Template guidance: every section below carries a comment saying what goes
     there (What), what a strong entry has (Good) and a one-line example
     (Example). Delete each comment when you fill its section. This is the
     record of every webhook we receive and send, read by the engineer
     debugging an integration and by support answering "did you send it".
     Delete Inbound or Outbound when the service has none of it. Secrets
     appear by name only, never a value. -->

Last reviewed: <YYYY-MM-DD> by <name>.

## Inbound

<!-- What: one row per provider we accept webhooks from, with the rules
     every handler follows.
     Good: the signature scheme is copied from the provider's docs, or says
     "scheme: assumed, confirm against provider docs"; the handler is a
     path:line; dedupe is on the provider's event id, never a payload hash;
     `webhook_events` rows outlive the provider's retry window plus any
     manual resend, not a fixed 24 h.
     Example: "| Razorpay | `POST /webhooks/razorpay` | HMAC-SHA256 over the
     raw body, header `X-Razorpay-Signature` | `RAZORPAY_WEBHOOK_SECRET` |
     5 min | `webhook_events` | `internal/webhooks/razorpay.go:41` |
     `payments-sync` |" -->

| Provider | Endpoint | Signature scheme | Secret name | Replay window | Event table | Handler | Job |
| --- | --- | --- | --- | --- | --- | --- | --- |
| <provider> | `POST /webhooks/<provider>` | HMAC-SHA256 over `<what is signed>`, header `<name>` | `<SECRET_NAME>` | 5 min | `webhook_events` | `<path:line>` | `<job name>` |

Rules: raw body verified with a constant-time compare before parsing;
duplicate `(provider, event_id)` returns 200 with no work; the handler
acks inside 1 s and the job does the rest; both current and previous
secrets verify during a rotation window.

## Outbound

<!-- What: the events we send to consumers, how they are delivered, who
     receives them and how their secrets rotate, in the four subsections.
     Good: every sent event is catalogued, and every consumer can see its
     own delivery log and replay from it; that log is the support tool.
     Example: "Events: 6 catalogued, 3 consumers, log at
     `/settings/webhooks/deliveries`." -->

### Event catalogue

<!-- What: one row per event we send: name, version, trigger, schema and
     sample.
     Good: names follow `<domain>.<noun>.<verb>`; the schema and the sample
     are files in the repository, not prose; the row count equals the
     "events: N" the skill printed.
     Example: "| `billing.invoice.paid` | 1 | an invoice moves to paid |
     `api/events/invoice-paid.v1.json` | `api/events/samples/invoice-paid.json` |" -->

| Event | Version | Fires when | Payload schema | Sample |
| --- | --- | --- | --- | --- |
| `<domain>.<noun>.<verb>` | 1 | <condition> | `<path to schema>` | `<path to sample>` |

### Delivery

<!-- What: the headers, schedule, retry rules and limits every delivery
     follows; replace the placeholders with the built values.
     Good: `X-Webhook-Id` is the event id, the same on every attempt and
     replay, so consumers can dedupe; retries on 5xx, timeouts and
     connection errors only; the dead letter and the log table are named.
     Example: "Rate limit per consumer: 10 per second. Consumer view at
     `GET /v1/webhooks/deliveries`." -->

- Headers: `X-Webhook-Id`, `X-Webhook-Timestamp`, `X-Webhook-Signature: v1=<hmac-sha256(secret, id.timestamp.body)>`.
- Schedule: 0 s, 1 min, 5 min, 30 min, 2 h, 12 h, 24 h; success is any 2xx inside 10 s.
- Retry on 5xx, timeout, connection error. No retry on 4xx.
- After the last attempt: dead letter, endpoint marked failing, owner notified.
- Rate limit per consumer: <n> per second. Circuit breaker: pause after 100 consecutive failures.
- Log table: `webhook_deliveries`; consumer view at `<endpoint or page>`; replay by delivery id; a replay keeps the event id (`X-Webhook-Id`).

### Consumers

<!-- What: one row per external endpoint we deliver to.
     Good: one secret per consumer, by name; the status is live, failing
     (marked after the last attempt dead-letters) or paused (circuit
     breaker after 100 consecutive failures); an owner on our side.
     Example: "| Northwind ERP | `https://erp.northwind.in/hooks/ledger` |
     `billing.invoice.paid` | `WH_SECRET_NORTHWIND` | 10/s | live |
     Anita Rao |" -->

| Consumer | Endpoint | Events | Secret name | Rate limit | Status | Owner |
| --- | --- | --- | --- | --- | --- | --- |

### Secret rotation

<!-- What: how a consumer's signing secret is replaced without a missed
     delivery.
     Good: names the endpoint or command that issues the new secret and the
     24 h window when both signatures are sent; inbound, both current and
     previous secrets verify for the rotation window.
     Example: "Issue: `POST /v1/webhooks/consumers/{id}/secret`; the old
     secret stops signing 24 h later." -->

Issue a new secret to the consumer, sign every delivery with both for 24 h, drop the old. Consumers verify with whichever matches.

## Verification for a consumer (copy into their docs)

<!-- What: the steps a consumer follows to verify our signature, ready to
     paste into their documentation.
     Good: matches the Delivery headers exactly (what is signed, the `v1=`
     prefix, the 5 minute window); tells them to compare in constant time
     and to dedupe on `X-Webhook-Id`, not on the payload.
     Example: "In Python: `hmac.compare_digest(expected, received)`." -->

1. Read the raw body.
2. `expected = hmac_sha256(secret, id + "." + timestamp + "." + body)`.
3. Constant-time compare with the `v1=` value.
4. Reject if `now - timestamp > 5 min`.
5. Deduplicate on `X-Webhook-Id`.
