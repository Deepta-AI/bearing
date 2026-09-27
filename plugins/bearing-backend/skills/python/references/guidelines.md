# Python guidelines

## Project shape

- One package, `app`, with `main.py` as the only wiring module. Everything
  else is a plain module with one reason to change.
- Packages are named for what they provide (`invoice`, `repositories`,
  `health`), never `utils`, `common`, `helpers`, `misc`.
- `app/api` knows HTTP and Pydantic. `app/domain` knows business rules and
  domain types. `app/db` knows SQLAlchemy. Imports only point downward:
  api imports domain and db; domain imports db types; db imports nothing
  above it.
- A module under 400 lines; a function under 30. Split by domain, not by
  layer, once it grows.

## Database: SQLAlchemy Core-style repositories

- The stack is SQLAlchemy 2 async on asyncpg, used Core-style: declarative
  models with `Mapped[...]` and `mapped_column` for types and Alembic
  autogenerate, `select()` statements built in repositories, no lazy loading
  and no relationship magic. Why not plain asyncpg: hand-written row mapping
  and no autogenerate cost more than the ORM saves. Why not full ORM style:
  lazy loads and implicit flushes do not survive async and hide N+1s.
- Repositories own SQL. One class per aggregate, methods take an
  `AsyncSession` and return typed models or plain dataclasses, never a `Row`
  or a `dict`. No `select(Model)` anywhere outside `app/db/repositories`.
- Services own transactions: `async with session.begin():` wraps the unit of
  work. A repository never calls `commit()`.
- Every list query is bounded: `limit` with a validated maximum, a stable
  `order_by`. An unbounded `select` is a finding.
- Keyset paging orders by columns that cannot be NULL, or handles NULL
  explicitly: SQL comparisons with NULL are unknown, so a NULL sort key
  drops the row from every page after the first and breaks the cursor.
  Before choosing the sort key, read its nullability in the schema and
  query the data (seed, fixtures) for real NULLs; a comment such as "NULL
  only while draft" is a claim, not a constraint. Then exclude those rows
  with a stated reason, order by `COALESCE(col, fallback)` (and index
  that expression), or pick a NOT NULL column, and test paging through
  such a row.
- Relationships that are needed are loaded explicitly with `selectinload`
  or a join in the repository. `lazy="raise"` on every relationship so a
  missed load fails loudly instead of doing a hidden query.
- `expire_on_commit=False` on the session factory; objects stay usable after
  the transaction ends.
- Migrations are safe to re-run: `IF NOT EXISTS` on DDL whenever the
  runner could apply a file and crash before recording it.
- Migrations: Alembic, one concern per file, a working `downgrade`, an index
  decision comment for every new filter. Autogenerate output is a draft: read
  every line, delete the noise, name every constraint through the
  `naming_convention` in `app/db/base.py`.

## HTTP with FastAPI

- Routers per resource under `app/api/<resource>/router.py`; schemas next
  to them in `schemas.py`. `response_model` on every route, an explicit
  `status_code` on every non-200.
- Request models are `BaseModel` with `model_config = ConfigDict(extra=
  "forbid")`. Unknown fields are a 422, not silently dropped.
- Dependencies through `Annotated[T, Depends(get_t)]`. Settings, sessions,
  services and the current user are dependencies, never imports of a global.
- A route parses, calls one service method, returns a schema. No SQL, no
  business rule, no `try` that builds an error body.
- Pure ASGI middleware, not `BaseHTTPMiddleware`: the latter breaks
  streaming responses and contextvars.
- `docs_url` and `redoc_url` are off in production.
- An inbound webhook follows the Webhooks section of
  `review-checklist.md` from the first line: raw-body signature before
  parsing, fail closed without a secret, event id recorded with the
  effect, the sender's contract read for routing and amount semantics.

## Documents are part of the change

- The API contract, README and ADRs are read before the code, and the new
  code follows the code where they disagree only after checking which one
  is right. A contract document that is wrong about the surface you are
  changing is corrected in the same change (the clients are built from
  it), and the final message says so; one that is wrong elsewhere is
  reported, not rewritten.

## Async

- Every function on a request path is `async def` and awaits its IO. A sync
  function that does IO is called through `run_in_threadpool`.
- `httpx.AsyncClient` for outbound calls, created once in the lifespan with
  a timeout, closed on shutdown. Never `requests`.
- Background work is a task with an owner: `asyncio.TaskGroup` for bounded
  fan-out, a queue with a consumer for fire-and-forget. A bare
  `asyncio.create_task` whose result nobody awaits is a finding.
- `asyncio.timeout()` around anything that talks to the network.

## Errors

- Domain exceptions subclass `DomainError` with a `status_code` and a
  `code`. Services raise them; `register_exception_handlers` maps them to
  the JSON envelope once. `HTTPException` appears only in auth dependencies.
- Wrap with context: `raise NotFoundError(f"invoice {id}") from exc`. The
  chain reads like a stack trace.
- `except Exception` only at a boundary that logs and re-maps. Never a bare
  `except:`, never `except Exception: pass`.
- Validation failures are 422 with the Pydantic error list in `details`.

## Configuration

- `Settings(BaseSettings)` in `app/core/config.py` with typed fields,
  `Literal` for enumerations, defaults for everything that is safe to
  default and no default for secrets; secrets are `SecretStr`. Construction fails fast and names
  every bad variable at once.
- `get_settings()` is `lru_cache`d and is the one allowed module-level
  singleton. Tests build `Settings(_env_file=None, ...)` explicitly.
- `.env.example` lists every variable with a placeholder.

## Logging and observability

- structlog, JSON in production, console in development. Request id, method,
  path, status and duration on every request log, bound through
  `structlog.contextvars` so every line in the request carries them.
- stdlib loggers (uvicorn, sqlalchemy) route through the same formatter.
- Never log a body, a token, a password or an email. Log ids.
- `/healthz` (process up) and `/readyz` (database reachable) on every
  service.

## Testing

- pytest with `asyncio_mode = "auto"`; `async def` tests need no marker.
- `httpx.AsyncClient` over `ASGITransport` for routes, with
  `asgi_lifespan.LifespanManager` so `app.state` is populated. Override
  dependencies with `app.dependency_overrides`, never by patching modules.
- Repository tests are `@pytest.mark.integration`, run against Postgres in
  Docker after `alembic upgrade head`, each test inside a transaction that
  is rolled back.
- Deterministic: no `time.sleep`, no real clock (inject `now`), no network.
- A bug fix ships with the test that reproduces it. Coverage floor is 80%
  and rises, never falls.

## Typing and style

- mypy strict on `app` and `tests`; the pydantic plugin is on. No `Any`
  unless the value is genuinely open (JSON payloads use
  `dict[str, object]`). `# type: ignore[code]` only with the code and a
  reason on the same line.
- ruff decides style. Nothing is discussed in review that a tool decides.
- Docstrings on every public module, class and function, one line, saying
  what it is for. Comments explain why.
- `Annotated` types, `X | None` unions, `list[...]` builtins. No `typing.
  Optional`, `List`, `Dict`.
- Immutable by default: `frozen=True` dataclasses for domain values,
  `Field(default_factory=...)` for any mutable default.
