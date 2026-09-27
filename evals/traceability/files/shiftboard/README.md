# shiftboard

Lets staff swap shifts with each other, with manager approval and the
statutory 11 hour rest rule enforced.

## Layout

- `cmd/api`: HTTP entry point
- `internal/swap`: swap requests, manager decisions, rest rule
- `internal/audit`: swap audit trail
- `migrations`: Postgres schema

## Running

    make check
