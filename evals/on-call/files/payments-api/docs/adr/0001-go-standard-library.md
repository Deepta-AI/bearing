# ADR-0001: Go standard library only

Status: Accepted

## Context
The payments service handles card data flows and must pass the PCI DSS
review each year. Every third-party dependency adds to that review.

## Decision
payments-api uses the Go standard library only. Metrics are written by hand
in Prometheus text format.

## Consequences
No client library for metrics or tracing; small surface to review.
