# __REPO_NAME__

Node service (Fastify). `make help` lists every command; `make check` is the gate.

## Run

```
cp .env.example .env
make setup          # pnpm install (writes pnpm-lock.yaml; commit it), git hooks
make db && make migrate
make dev            # http://localhost:8080
```

`make dev` serves `/healthz`, `/readyz` and `/metrics`. `make check` prints
one `<gate>: N ... checked` line per gate (format, lint, typecheck, unit
tests, dependency audit) and a final tally. A gate whose tool is missing
prints `SKIPPED` and the tally fails; `BEARING_ALLOW_SKIP=1 make check` lets a
laptop through and is never set in CI. `make test-integration` needs
Postgres and is a CI job, not part of `check`.

## Layout

See `AGENTS.md` and the `node` skill for the conventions. `src/server.ts`
wires and owns shutdown, `src/app.ts` builds the Fastify instance,
`src/routes` serves, `src/<domain>` decides, `src/db` persists (Drizzle
schema and client), `drizzle/` holds the generated SQL migrations.
`make migrate-new name=add_invoices` writes the next migration from
`src/db/schema.ts`; read it before committing.

## Image

```
docker build -t __REPO_SLUG__ .
docker run --rm -p 8080:8080 -e DATABASE_URL=... __REPO_SLUG__
```
