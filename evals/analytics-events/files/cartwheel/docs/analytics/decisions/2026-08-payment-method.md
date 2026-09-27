# payment_submitted: `method` becomes `payment_method`

Status: Accepted (2026-08-14)

## Context

The collector flattens event properties into warehouse columns beside its
own request columns (docs/analytics/collector.md). A property called
`method` lands in the same column as the HTTP method of the collect
request, so the warehouse reads `POST` for every `payment_submitted` row
that sends `method`.

## Decision

Rename the property to `payment_method` (`enum(card,upi,cod)`) on every
platform. Mobile ships it in 4.12; web and the event sheet follow.
