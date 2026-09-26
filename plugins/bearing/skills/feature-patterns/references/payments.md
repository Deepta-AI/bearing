# Pattern: payments

Money moves once, is recorded twice (a ledger), and is confirmed by the
provider's webhook, never by the client's redirect. Card data never
touches the servers.

Markers: `stripe|razorpay|adyen|braintree|paypal|webhook|idempotency|Idempotency-Key|ledger|payment_intent|checkout.session`
Decision keys (ADR grep): `payment`, `provider`, `ledger`, `pci`

## Decision questions

1. Provider and integration: hosted checkout page or elements (recommend
   hosted checkout or the provider's client-side elements: PCI SAQ A);
   raw card fields (SAQ D, a compliance programme; avoid).
2. What is charged: one-off, subscription, usage, or a marketplace with
   payouts? Subscriptions and payouts use the provider's objects, never a
   home-grown scheduler.
3. Currency and rounding: minor units (integer paise or cents) end to
   end; the display layer formats. Multi-currency needs a currency column
   on every amount.
4. Refunds: full, partial, who may issue, within what window? A refund
   is a new ledger entry, never an edit.
5. Idempotency: the key comes from the payment intent, not the attempt.
   The client generates it once per checkout (or derives it from an
   immutable id, `charge:v1:<order_id>`) and reuses it on every retry;
   a fresh UUID per attempt makes every retry a new charge. The server
   claims it with a unique insert before the provider call (a unique
   violation replays the stored outcome, or 409 while in progress, and
   a reused key with a different body is 422), stores the outcome with
   it, and retains it longer than the longest path that can resend the
   intent: client retries, the job retry chain, dead-letter replay and
   the provider's dispute window. The provider call carries the same
   key.
6. Reconciliation: daily job comparing the provider's settlement report
   with the ledger; the diff is a metric and an alert.

## Data model

```
payments(id, tenant_id, customer_id, provider, provider_ref, amount_minor, currency,
         status[created|requires_action|succeeded|failed|refunded|partially_refunded],
         idempotency_key unique, created_at, updated_at)
ledger_entries(id, payment_id, account[receivable|cash|fees|refunds], debit_minor, credit_minor,
               currency, occurred_at, provider_event_id unique, note)  -- append only
webhook_events(id, provider, event_id unique, type, payload jsonb, received_at, processed_at, error)
refunds(id, payment_id, amount_minor, reason, provider_ref, status, requested_by, created_at)
```

Every ledger entry balances (sum of debits equals sum of credits per
payment); a check constraint or a nightly job asserts it.

## Flow

1. `POST /payments` with `Idempotency-Key`: create `created`, call the
   provider with the same key, store `provider_ref`, return the client
   secret or the hosted URL.
2. Client completes on the provider's surface.
3. Webhook `payment.succeeded`: verify the signature, insert into
   `webhook_events` (unique `event_id` makes redelivery a no-op), then in
   one transaction set the payment status and write the ledger entries.
4. The redirect page reads the payment status; it never marks anything.
5. Refund: `POST /payments/{id}/refunds` with a key; provider call; the
   `refund.succeeded` webhook writes the ledger entry.
6. Nightly reconciliation against the settlement report.

## Failure modes

| Fault | Handling |
| --- | --- |
| client double-submits | same `Idempotency-Key` returns the first outcome; a different key for the same cart is blocked by an `open payment` check |
| webhook delivered twice or out of order | `event_id` unique; status transitions are guarded (a `failed` after `succeeded` is logged, not applied) |
| webhook never arrives | a job polls the provider for payments `created` older than 15 minutes |
| provider timeout after the charge | the idempotent retry with the same key returns the existing charge; never a second charge |
| signature check skipped | a test posts an unsigned webhook and expects 400 |
| amount tampered in the client | the amount comes from the server-side cart, never from the request that creates the payment |
| currency mismatch | currency on every row; a payment in the wrong currency is rejected before the provider call |
| refund exceeds the payment | sum of refunds constrained to the amount, in the database |
| card data in logs | request logging strips `card`, `pan`, `cvv`; the threat model lists the fields |

## Tests to write

- two `POST /payments` with the same key create one provider call and one row
- two concurrent `POST /payments` with the same key create one provider call (one wins the unique insert, the other gets the stored outcome or 409)
- the same key with a different amount is 422, not the first outcome
- a key replayed after the retry and dead-letter window still returns the first outcome (retention outlives the longest redelivery path)
- a replayed webhook changes nothing (row count, ledger sum)
- an unsigned webhook is 400 and not stored as processed
- ledger balances after success, after a partial refund, after a full refund
- a `failed` event after `succeeded` is recorded and ignored
- the poll job resolves a `created` payment whose webhook was dropped (provider stub)
- reconciliation flags a settlement line with no ledger entry
- amounts are integers in minor units end to end (a `decimal` in the API is a finding)

## Per-stack pointers

- Go: the provider's official SDK; webhook verification helper; `pgx` transaction around status plus ledger.
- Python: official SDK; FastAPI raw body for signature verification (do not parse before verifying).
- React and React Native: the provider's elements or hosted checkout; never a card input of your own; RN uses the provider's native SDK.
- Android and iOS: the provider's native SDK; Google Pay and Apple Pay through it; no card fields drawn by the app.
- Threat model (`threat-model`) and `vapt-report` before the first live charge.
