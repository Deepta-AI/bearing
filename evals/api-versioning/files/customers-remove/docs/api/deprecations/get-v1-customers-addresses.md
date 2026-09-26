# Deprecation: GET /v1/customers/{id}/addresses

| Field | Value |
| --- | --- |
| Deprecated on | 2026-05-17 |
| Sunset (removal not before) | 2026-08-15 (90 days notice) |
| Successor | `GET /v2/customers/{id}/addresses` |

## What changes for you

v1 returns a bare JSON array. v2 returns `{ "data": [...], "next_cursor": ... }`.
Read `data` instead of the top level array.
