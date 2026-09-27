# ADR-0004: audit log retention

Status: Accepted (2026-04-02)

## Context

The payment partner agreement requires us to keep order and refund audit
events for at least 400 days and to produce them on request.

## Decision

Audit events go to the CloudWatch log group /orders/audit, retained for 400
days (terraform/logs.tf). Application logs go to /orders/app and are not
subject to this requirement.

## Consequences

The retention of /orders/audit must not be lowered without legal sign-off.
