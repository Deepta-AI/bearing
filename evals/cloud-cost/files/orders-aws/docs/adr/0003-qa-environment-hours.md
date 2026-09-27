# ADR-0003: qa environment hours

Status: Accepted (2026-03-11)

## Context

The regression suite runs against qa every night from 01:00 to 05:00 IST, and
the partner QA team in Toronto tests on qa during their working day, which is
the Indian night.

## Decision

The qa environment (EKS cluster orders-qa and orders-db-qa) stays up from
Monday 00:00 IST to Saturday 06:00 IST. It may be scaled to zero from
Saturday 06:00 to Monday 00:00 IST. The dev environment has no hours
requirement.

## Consequences

qa compute cannot follow an office-hours schedule. Revisit if the partner
team or the nightly suite moves.
