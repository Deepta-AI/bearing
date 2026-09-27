# ADR-0003: Card data stays with the payment provider

Status: Accepted (2026-07-02)

## Context

Taking card numbers on our own pages, or storing them in any form, puts this
service and its database in PCI DSS scope (SAQ D instead of SAQ A): quarterly
scans, a yearly assessment and key management we are not staffed for.

## Decision

Card details are entered only on the provider's hosted page. For saved cards
we keep the provider's card token, the brand, the last four digits and the
expiry month and year. We never receive, store, log or encrypt a full card
number or a CVV, not even temporarily.

## Consequences

Paying with a saved card goes through the provider's token API. A feature that
needs the full card number on our side needs a new ADR that supersedes this
one first.
