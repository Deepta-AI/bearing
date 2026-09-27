# ADR-0001: Google Cloud, asia-south1 only

Status: Accepted

## Context

The ledger holds customer balances and transaction history. Our payments
regulator requires that this data, and every copy of it, is stored only in
India.

## Decision

All ledger infrastructure runs on Google Cloud in `asia-south1` (Mumbai).
Every resource that stores ledger data or credentials for it keeps that data,
including backups, replicas, snapshots and secret replicas, in `asia-south1`.
Multi-region and global storage locations are not allowed for such resources,
even when they include India.

## Consequences

- The `region` variable of every environment root is validated to
  `asia-south1`.
- Any new data store states its storage location for backups and replicas
  explicitly rather than relying on a provider default.
