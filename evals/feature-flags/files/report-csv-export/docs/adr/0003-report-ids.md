# ADR 0003: Report ids are opaque

Status: Accepted (2026-05-14)

## Decision

Report ids in URLs, emails and archive keys are opaque strings. Clients
never parse them, and the service never derives one from a title.
