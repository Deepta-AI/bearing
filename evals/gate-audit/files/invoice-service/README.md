# invoice-service

Issues invoices and emits billing events for the ledger.

## Checks

`make check` runs every gate: lint, the unit tests, the event schema check and
the migration check. CI runs the same gates on every merge request, and the
migration check blocks a merge when a migration has no down script.

Enable the local hook once with `git config core.hooksPath .githooks`.

## Layout

- `src/billing/` the service code
- `db/migrations/` numbered up and down SQL migrations
- `fixtures/events.json` sample events the ledger team replays
- `docs/event-schema.json` the event contract agreed with the ledger team
