# ADR-0002: Migrations are append-only

- Status: Accepted
- Date: 2026-07-09

## Context

The deploy pipeline applies every file in `migrations/` to staging when a
change reaches `main`, and to production on the next release. It records each
file name it has applied and never runs a file twice.

## Decision

A migration that has reached `main` is never edited, renamed or deleted. A
schema change is a new file with the next free number (`NNNN_<slug>.sql`),
taken from `main` at the time the branch is merged, not when it was cut.

## Consequences

An edit to an applied migration is silently skipped by the pipeline, so the
schema in staging and production would differ from the files. Two branches
that pick the same number must renumber before merging.
