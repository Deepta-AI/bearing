# ADR-0002: Background jobs run from a Postgres jobs table

Status: Accepted (2026-01-19)

## Context
We need a few kinds of deferred work (invoice emails first). Volume is low
and we do not want to run a broker.

## Decision
We will queue background work as rows in the `jobs` table, polled by
`cmd/worker`. Each job has a kind, a JSON payload and a run_at time.

## Consequences
Throughput is bounded by the poll (see internal/jobs/worker.go). Revisit if
any job kind needs more than a few jobs a second sustained.
