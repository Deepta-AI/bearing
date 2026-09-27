# invoices-api

The billing API behind the finance dashboard: customers, invoices and the
payment provider's webhooks, for every organisation on the platform. Each
API key belongs to one organisation and sees only that organisation's data.

FastAPI and Pydantic v2 on Python 3.12, SQLite through the standard
library `sqlite3` module (see docs/adr/0001). Dependencies are installed
from the system image; there is no lock file yet.

    make check    # ruff check . and pytest
    make dev      # uvicorn on :8000

Settings come from `INVOICES_*` environment variables (see .env.example).

## Layout

- `app/main.py`: create_app, lifespan, routers
- `app/<resource>/`: router.py (HTTP), schemas.py (Pydantic), service.py
  (rules), repository.py (the only place SQL lives)
- `app/db.py`: the Database wrapper; every call runs in the threadpool
- `migrations/NNNN_name.sql`: applied in filename order at startup by
  `app/migrate.py`, which records each filename in `schema_migrations`
- `docs/api.md`: the contract the dashboard is built against
- `docs/adr/`: decisions

## Migrations

A migration that has been released is never edited: production records
applied filenames and will not run a changed file again. Add a new file.
Migrations 0001 to 0003 are in production.
