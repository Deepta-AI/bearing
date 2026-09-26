# ADR-0003: MSG91 for outbound SMS

Status: Accepted (2026-03-02)

## Context
OTP logins need SMS in India. MSG91 has DLT template support and an
Indian billing entity.

## Decision
We will send all outbound SMS through MSG91 via internal/sms.

## Consequences
Our plan allows 20 requests a second. A second provider needs a new ADR.
