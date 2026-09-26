# ADR-0002: Money is integer paise end to end

Status: Accepted

## Context

A float rupee amount cannot represent most paise values exactly. In 2025 a
settlement report drifted by a few paise per thousand orders because amounts
were parsed as floats and truncated.

## Decision

Every amount is an integer number of paise: in the database, in memory and
in the public API (fields named `*_paise`). The API rejects a non-integer
amount with 422; it never converts rupees to paise.

## Consequences

Clients format rupees for display themselves. Any conversion from a decimal
string happens in the client, not in this service.
