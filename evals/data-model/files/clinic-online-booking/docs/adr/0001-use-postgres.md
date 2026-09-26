# 0001. Use PostgreSQL 16 as the only database

Status: Accepted

## Context

A small team, one service, relational data with strong consistency needs.

## Decision

We will use PostgreSQL 16 for all application data. No second store
without a new ADR.

## Consequences

Search and analytics features must fit in Postgres or come with an ADR.
