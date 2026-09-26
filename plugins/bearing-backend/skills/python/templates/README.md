# __REPO_NAME__

Python service (FastAPI). `make help` lists every command; `make check` is the gate.

## Run

```
cp .env.example .env
make setup
make db && make migrate
make dev
```

`make dev` serves on http://localhost:8080 with `/healthz`, `/readyz` and
`/docs` outside production.

## Layout

See `AGENTS.md` and the `python` skill for the conventions. `app/main.py`
wires, `app/api` serves, `app/domain` decides, `app/db` persists, `alembic/`
migrates. `make migrate-new name=add_invoices` writes the next migration.
