# 0003 Postgres as the primary store

## Status

Accepted (2025-11-20)

## Context and Problem Statement

Export state and customer settings need transactions.

## Considered Options

- Postgres
- DynamoDB

## Decision Outcome

Chosen option: Postgres.

## Consequences

One database to back up and migrate.
