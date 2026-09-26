# 4. Redis for shared cache and counters

Status: Accepted

## Context

The catalogue is read far more than it changes, and several upcoming
features need state shared between replicas.

## Decision

We will run one ElastiCache Redis cluster (partner-cache) for the
catalogue cache and for any counter that must be shared across
replicas. Nothing in it is the source of truth.

## Consequences

One more managed service; losing Redis must degrade the API, not stop it.
