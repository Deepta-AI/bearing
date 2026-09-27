# ADR-0002: Marts keep history the raw schema does not

Status: Accepted (August 2026)

## Context

The loader keeps 60 days in `raw` (docs/sources.md). Finance reads
`marts.fct_orders_daily` back to January 2024 for year-on-year reports.

## Decision

Fact marts are incremental by day and are the only copy of history older
than 60 days. They are never rebuilt with `--full-refresh` in production:
a full refresh rebuilds only from what `raw` still holds and silently
drops every older partition. A correction is a backfill of the affected
days, one day at a time, oldest first.

## Consequences

A fix to a fact mart must name the affected days, and those days must
still be in `raw` when the backfill runs. Schema changes to a fact mart
go through a new model and a swap, not a rebuild.
