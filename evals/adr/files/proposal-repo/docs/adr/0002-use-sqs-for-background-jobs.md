# 0002 Use SQS for background jobs

## Status

Accepted (2025-11-03)

## Context and Problem Statement

Exports take minutes and must not run inside a web request.

## Considered Options

- SQS with a Python worker
- A cron job polling Postgres

## Decision Outcome

Chosen option: SQS with a Python worker, because it needs no servers to run.

## Consequences

Job payloads must fit in one SQS message.
