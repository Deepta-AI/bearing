# ADR-0002: Enforce the rest rule in the swap service

Status: Accepted

## Context

The 11 hour rest rule (SHF-13) could be checked by the roster UI or by
this service.

## Decision

The swap service checks the rule on every request; the UI only mirrors it.

## Consequences

The rule has one implementation, in internal/swap/rest.go.
