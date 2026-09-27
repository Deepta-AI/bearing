# Backlog: paygate

## EP-02 Capture

### US-02-001 Capture an authorised payment

- Covers: capture on dispatch

Acceptance criteria:

- AC-US-02-001-1: Capturing up to the authorised amount succeeds.

### US-02-002 Refuse over-capture

Acceptance criteria:

- AC-US-02-002-1: A capture above the authorised amount is refused.

### US-02-003 Capture webhook

Acceptance criteria:

- AC-US-02-003-1: A gateway webhook of captured or settled marks the payment captured.
- AC-US-02-003-2: An unknown webhook status leaves the payment pending.

## EP-03 Refunds

### US-03-001 Full refund

As a support agent I want to refund a whole order so that a cancelled
order costs the customer nothing.

Acceptance criteria:

- AC-US-03-001-1: A full refund returns everything captured and not yet refunded.
- AC-US-03-001-2: A payment with nothing captured cannot be refunded.

### US-03-002 Refunds are idempotent

As a support agent I want a retried refund request to refund once so that a
double click never pays out twice.

Acceptance criteria:

- AC-US-03-002-1: A second request with the same idempotency key returns the first refund.
- AC-US-03-002-2: A second request with the same key does not change the refunded total.

### US-03-003 Partial refund

As a support agent I want to refund one item of an order so that the
customer keeps the rest.

Acceptance criteria:

- AC-US-03-003-1: A partial refund of up to the amount left to refund succeeds.
- AC-US-03-003-2: Partial refunds together can never exceed the captured amount.

## EP-04 Support console

### US-04-001 Refund from the support console

Status: planned, next branch (feature/refund-api), after the refund rules
on feature/refunds are merged.

As a support agent I want a refund button in the console so that I do not
need an engineer to refund a customer.

Acceptance criteria:

- AC-US-04-001-1: POST /v1/refunds with a payment id, an idempotency key and an optional amount issues a full or partial refund through the refund store.
- AC-US-04-001-2: Every refund is written to the refunds table and the payment's refunded total is updated in the same transaction.
