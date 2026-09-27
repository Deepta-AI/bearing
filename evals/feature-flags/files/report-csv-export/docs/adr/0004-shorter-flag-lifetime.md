# ADR 0004: Shorter flag lifetime

Status: Accepted (2026-08-12)

## Context

Two flags went past their 90-day target in the first quarter under
ADR 0002, and nobody noticed until an incident review.

## Decision

- A flag added on or after 2026-09-01 has a removal target date no more
  than 45 days after the day it is added. This replaces the 90-day limit
  of ADR 0002 for those flags; rows added before then keep their dates.
- The rest of ADR 0002 stands.
