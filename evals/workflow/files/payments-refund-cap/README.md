# payments

Captures and refunds card payments for merchants. Go, standard library only.

## Working here

- One branch per ticket: `feature/<TICKET>-<slug>`, cut from `main`.
- Each task keeps a short shared record in `docs/progress/<TICKET>.md`,
  committed on its branch.
- `make check` (vet and tests) must pass before a merge request is opened.
- Database changes go in `migrations/`, numbered in order. See
  `docs/adr/0002-append-only-migrations.md` before touching that folder.

## Layout

- `cmd/api`: the HTTP server.
- `internal/refunds`: the refunds endpoint and its store.
- `migrations`: Postgres schema, applied by the deploy pipeline.
