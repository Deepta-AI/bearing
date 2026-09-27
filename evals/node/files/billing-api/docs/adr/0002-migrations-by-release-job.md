# ADR-0002: Migrations run from the release job

Status: Accepted (2026-03-02)

## Decision

Schema changes are numbered SQL files in migrations/ applied by
`make migrate` (scripts/migrate.ts) in the release job, before the new
version starts. The server never migrates on boot: three replicas start at
once and would race.

A migration file that has been applied anywhere is never edited; a change is
a new file with the next number. Every new query filter comes with an index
decision in its migration (the index, or a comment saying why none).
