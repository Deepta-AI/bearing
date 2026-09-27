# ADR-0002: Private networking for data stores

Status: Accepted

## Context

GKE workloads reach managed services (Cloud SQL, Memorystore) inside the
VPC. Public endpoints on data stores have been the root cause of two
incidents at a previous employer of the team.

## Decision

- Data stores have no public IP. Cloud SQL uses private IP only, reached
  through private service access (a reserved internal range peered with the
  service producer network).
- The private service access range is allocated from the environment's own
  /16 and must not overlap the node, pod or service ranges of that
  environment. The live ranges are the ones in `envs/<env>/main.tf`.
- Network pieces (ranges, peering) live in `modules/network`.

## Consequences

Adding the first managed data store also adds the private service access
reservation and peering to the network module.
