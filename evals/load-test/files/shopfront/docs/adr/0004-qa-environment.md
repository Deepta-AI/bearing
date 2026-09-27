# ADR-0004: qa environment sizing

Status: Accepted (2026-05-04)

## Context

qa was costing as much as production while idle most of the day.

## Decision

qa runs one replica with half a CPU and a 256Mi memory limit
(deploy/qa/values.yaml), against six replicas of one CPU and 512Mi in
production. qa is scaled to zero from 22:00 to 07:30 IST every day by the
scheduled qa-scale-down and qa-scale-up jobs in .gitlab-ci.yml. A team that
needs qa overnight pauses the qa-scale-down schedule in GitLab and says so
in the platform channel.

## Consequences

Numbers measured on qa describe one small pod, not production.
