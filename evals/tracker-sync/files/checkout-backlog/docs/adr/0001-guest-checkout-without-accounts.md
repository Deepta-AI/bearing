# ADR-0001: Guest checkout without accounts

Status: Accepted (2026-06-18)

## Context

Half of first-time buyers abandon checkout at the sign-up step.

## Decision

Orders can be placed without an account. A guest order carries a contact
email and is found again by email plus order number. Converting a guest into
an account is allowed after the purchase, never required before it.

## Consequences

Guest orders have no user id; anything keyed by user must also accept a guest
email.
