# billing-api

The HTTP API behind the billing dashboard. TypeScript run directly by Node
(type stripping, Node 22.18 or later), `node:http` for the server,
`node:sqlite` for storage and `node:test` for tests. There are no npm
dependencies; see docs/adr/0001-no-runtime-dependencies.md before adding one.

Conventions every endpoint follows are in docs/API.md.

Invoices issued before July 2026 were imported from the old billing system
in the June cut-over; the import copied its rows as they were.

    make check     # every test under test/
    make dev       # local server on :8080
    make migrate   # apply pending migrations (the release job runs this before a deploy)

Layout: `src/routes/` parse and reply, `src/<domain>/service.ts` holds the
rules, `src/<domain>/repository.ts` holds the SQL. Relative imports carry the
`.ts` suffix because Node runs the sources as they are.
