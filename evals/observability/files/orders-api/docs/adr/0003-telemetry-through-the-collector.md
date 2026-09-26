# ADR-0003: Telemetry goes through the cluster collector

Status: Accepted

## Context

The platform team runs one OpenTelemetry Collector per cluster in the
`observability` namespace. It forwards traces to the tracing backend and
logs to the log store, and it does tail sampling: it keeps every trace
with an error, every trace slower than 1 s and 5 percent of the rest.

## Decision

- Services send OTLP over HTTP to
  `http://otel-collector.observability:4318`. The collector does not
  expose the gRPC port in our clusters.
- Services never export straight to a tracing or log backend.
- Services do not sample. The SDK keeps its default parent-based
  always-on sampler; sampling is the collector's job, so the traces of
  failed requests are always kept.

## Consequences

A service that sets a head sampler loses most of its error traces before
the collector can see them.
