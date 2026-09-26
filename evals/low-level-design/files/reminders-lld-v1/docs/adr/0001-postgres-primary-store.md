# ADR-0001: Postgres is the primary store

Status: Accepted (2025-11-04)

## Context
One service, one team, relational data (clinics, patients, appointments).

## Decision
We will keep all application data in one managed Postgres 16 instance per environment.

## Consequences
No second store without a new ADR.
