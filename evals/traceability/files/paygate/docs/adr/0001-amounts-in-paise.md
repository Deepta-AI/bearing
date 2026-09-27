# ADR-0001: Store money as integer paise

Status: Accepted

## Context

Capture (US-02-001, US-02-002) must never round.

## Decision

Every amount is a BIGINT count of paise in Postgres and an int64 in Go.

## Consequences

Display code formats rupees; no float ever holds money.
