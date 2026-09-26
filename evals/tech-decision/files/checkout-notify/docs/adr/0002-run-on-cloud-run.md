# 2. Run services on Cloud Run

Date: 2025-08-14

## Status

Accepted

## Context

Checkout is one HTTP service owned by three backend developers with no
dedicated operations engineer. Traffic is spiky around sale events.

## Decision

We will run checkout on Cloud Run in asia-south1, scaling from 1 to 20
instances.

## Consequences

No cluster to operate. Long-running background work does not fit a
request-scoped instance; revisit if we need many services or stateful
workloads that Cloud Run cannot host.
