---
paths:
  - "**/*.py"
---

# Python rules (loaded when a .py file is touched)

- Pydantic at every boundary: `response_model` on every route, request
  models with `extra="forbid"`, no `dict` past the router.
- Async all the way: no blocking call in an async path; sync work through
  `run_in_threadpool`; every network call has a timeout.
- Dependencies through `Annotated[T, Depends(...)]`; the only module-level
  singleton is `get_settings()`; engines live on `app.state`.
- Errors are `DomainError` subclasses raised in services and mapped once in
  `app/core/errors.py`; never a bare `except`, never log and re-raise.
- structlog with the request id bound; never log secrets, PII or bodies.
- Repositories own SQL and return typed models; services own transactions;
  every list query is bounded and ordered; `lazy="raise"` on relationships.
- Alembic: one concern per migration, a working `downgrade`, autogenerate
  output read line by line, an index decision for every new filter.
- mypy strict: no `Any`, no untyped `def`, `# type: ignore[code]` only with
  a reason on the same line.
- pytest `asyncio_mode = "auto"`: no `@pytest.mark.asyncio`, no
  `event_loop` fixture, no `time.sleep`, no network.
- `uv.lock` is committed and regenerated with `uv lock`, never edited.
