# ADR-0004: Uptime probes from the in-cluster blackbox exporter

Status: Accepted

## Context

We need to know when a public endpoint stops answering. The cluster
already runs Prometheus and Alertmanager (monitoring/).

## Decision

Probe public endpoints with the Prometheus blackbox exporter in the
`monitoring` namespace, through the public ingress hostnames so the
probe takes the same path as a customer. No external uptime SaaS.

## Consequences

An outage of the whole cluster also takes the probes down; the
Alertmanager watchdog (monitoring/alerts/meta.rules.yml) covers that.
