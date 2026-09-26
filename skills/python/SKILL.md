---
name: python
description: 'Conventions for Python services: Python 3.14, FastAPI, Pydantic v2, SQLAlchemy 2 async, Alembic, structlog, uv, ruff, pytest. Use when writing, reviewing or scaffolding "FastAPI", "Pydantic" or "Python service" code.'
allowed-tools: Read, Grep, Glob, Bash(uv run pytest:*), Bash(uv run ruff:*), Bash(uv run mypy:*), Bash(make:*)
---

# python

The Python stack on this standard: Python 3.14, FastAPI, Pydantic v2 with
pydantic-settings, SQLAlchemy 2 async on asyncpg with Core-style
repositories, Alembic for migrations, structlog for logs, uv for
dependencies, ruff for format and lint, mypy strict, pytest with
pytest-asyncio and httpx, pip-audit in CI.

## Inputs

- Python files: the repository as it is; no scaffold is needed. A
  different layout is handled under "On a foreign layout".
- Gate: `make check` when a Makefile has that target; else the native
  commands under Commands, one by one.
- `references/guidelines.md` and `references/review-checklist.md` ship
  with this skill. `new-repo` and `ci-pipeline` are suggestions for a
  repository without a Makefile or a pipeline, never prerequisites.

## When this skill is active

- Writing or changing `.py` files: apply `references/guidelines.md`. Read it
  once per session, then work.
- Reviewing a diff with Python files: apply `references/review-checklist.md`
  and report in the reviewer format.
- Scaffolding (`new-repo python-api <Name>`): `templates/` holds the
  skeleton and configs; `bin/brg-scaffold` copies them. Do not hand-copy. A
  command-line tool (no server, no database) is `new-repo python-cli
  <Name>` from `templates-cli/`: argparse, a console script, the same
  gates.
- Generating CI (`ci-pipeline`): `templates/.gitlab-ci.yml` is the source.

## Layout

```
app/main.py               wiring only: create_app, lifespan, middleware, routers
app/core/config.py        pydantic-settings, fails fast on a bad environment
app/core/logging.py       structlog configuration, stdlib routed through it
app/core/errors.py        DomainError family, mapped once to the JSON envelope
app/api/<resource>/       router.py (routes) and schemas.py (request/response)
app/domain/<domain>/      service.py: business rules, no SQL, no HTTP types
app/db/session.py         engine, session factory, the get_session dependency
app/db/models.py          SQLAlchemy declarative models (typed mapped_column)
app/db/repositories/      one class per aggregate; the only place SQL lives
alembic/                  migrations, NNNN_name.py with upgrade and downgrade
tests/                    unit tests; tests/integration/ needs Postgres
Makefile                  the only entry point: help setup dev check fix test doctor
```

## On a foreign layout

Hard rules anywhere: 1 (validation at the boundary, Pydantic or the
library the repository uses), 2, 4, 5, 6 (parameterised SQL in one
layer) and 7. Advisory: the directory layout, uv, Alembic, structlog
and the Makefile targets: use the dependency manager, migration tool
and logger the repository already has; propose a switch in an ADR,
never inside a feature change. Say which rule was relaxed and why.

## Rules that matter most

1. Pydantic at every boundary. A router receives and returns Pydantic models
   with `response_model` set; a raw `dict` never crosses the router.
2. Async all the way. No blocking call (requests, time.sleep, sync drivers,
   file IO) inside an async path; sync work goes through
   `fastapi.concurrency.run_in_threadpool`.
3. Dependencies come through `Depends`. No module-level singletons except
   `get_settings()`; engines and session factories live on `app.state` and
   are created in the lifespan.
4. Errors are domain exceptions (`NotFoundError`, `ConflictError`) raised in
   services and mapped once, in `app/core/errors.py`. Routers never build an
   error body.
5. structlog with a request id bound per request; never log a token, a
   password or a full request body.
6. Repositories own SQL and return typed models; services own transactions
   (`async with session.begin()`); no `select(Model)` in a router.
7. No `Any`, no untyped `def`, no `# type: ignore` without an error code and a
   reason. mypy runs strict on `app` and `tests`.
8. `make check` = ruff format check, ruff lint, mypy, pytest with coverage.
   CI runs the same target.

## Commands

Each target is used when the Makefile has it; the command after the
colon is the native form (`uv run <cmd>`, or the repository's own runner).

```
make setup         # uv sync (creates .venv and uv.lock), git hooks
make dev           # uvicorn app.main:app --reload
make check         # ruff format --check . ; ruff check . ; mypy app tests ; pytest
make fix           # ruff format . ; ruff check --fix .
make migrate       # alembic upgrade head
make migrate-verify  # up, snapshot, every Down, up again, diff the schema (CI integration job)
make migrate-new name=add_invoices   # alembic revision --autogenerate -m add_invoices
make test-integration                # pytest tests/integration (needs Postgres)
```

## Gotchas

- `DATABASE_URL` uses the `postgresql+asyncpg://` scheme everywhere. Alembic
  runs on the same async engine through `connection.run_sync` in `env.py`;
  never add psycopg2 just for migrations.
- pytest-asyncio runs in `asyncio_mode = "auto"`: plain `async def test_*`
  works, and `@pytest.mark.asyncio` is noise. Fixture loop scope is set in
  `pyproject.toml`; do not define an `event_loop` fixture.
- `uv.lock` is committed. CI runs `uv sync --locked` and fails when the lock
  is stale; run `uv lock` after touching dependencies, never edit the lock.
- `uv sync` does not install the project (`package = false`); `app` imports
  because pytest, alembic and uvicorn run from the repository root.
- `AsyncSession` objects are per request. Storing one on `app.state` or a
  module makes every concurrent request share a connection.
- Autogenerate only sees models imported by `alembic/env.py`. A new module
  under `app/db` must be imported there or its tables never appear.
