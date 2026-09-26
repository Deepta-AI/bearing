# ADR-0004: Availability and latency targets for orders-api

Status: Accepted

## Context

Merchants need checkout to work; order lookup backs the order status
page. The merchant agreement promises 99.5 percent monthly availability.

## Decision

- Availability: 99.5 percent of `POST /checkout` and `GET /orders/{id}`
  requests succeed over a rolling 30 days. A 5xx response is a failure; a
  4xx is not.
- Latency: 95 percent of `POST /checkout` requests complete within
  1.5 seconds over the same window.
- Health probes and metric scrapes are not user traffic and do not count.

## Consequences

Alerting is to page on these targets, not on resource usage.
