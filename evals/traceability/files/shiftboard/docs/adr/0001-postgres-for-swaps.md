# ADR-0001: Store swaps in the rostering Postgres database

Status: Accepted

## Context

Swaps (SHF-11) and manager decisions (SHF-12) need to join against the
roster tables, which already live in the rostering Postgres database.

## Decision

Swaps and their decisions are tables in the rostering database, changed
only through numbered files in migrations/.

## Consequences

No new datastore. Schema changes to swap tables need a migration and a
note in this ADR or a new one.
