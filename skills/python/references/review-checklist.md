# Python review checklist

For each item, either find the concrete failure or write "none found".

## Async correctness
- A blocking call in an async path: `requests`, `time.sleep`, a sync DB
  driver, `open()` on a large file, CPU work over a few milliseconds.
- A coroutine called without `await` (the result is a never-run coroutine
  object; ruff RUF006 and mypy catch some, the reviewer catches the rest).
- `asyncio.create_task` with no owner, no reference kept, no error handling.
- An `AsyncSession` stored on `app.state`, a module, or a class attribute
  and used across requests.
- A network call with no timeout.

## Database
- A relationship without `lazy="raise"`; a lazy load inside a loop (N+1).
- `select(Model)` outside `app/db/repositories`; a raw SQL string built
  with f-strings or `%`; `text()` with interpolated values.
- An unbounded query: no `limit`, no `order_by` on a paginated list.
- A `commit()` inside a repository; a transaction opened in a router.
- An Alembic migration with an empty or missing `downgrade`, an
  autogenerate diff committed unread, a new filter without an index
  decision, a lock held on a hot table.

## Pydantic and typing
- A Pydantic model with a mutable default (`items: list[str] = []`).
- A request model without `extra="forbid"`; a route without
  `response_model`; a `dict` returned past the router.
- `X | None` accepted and then used as `X` without a `None` branch.
- `Any`, an untyped `def`, `# type: ignore` without a code, `cast` used to
  silence rather than to narrow.

## Errors
- A bare `except:`; `except Exception: pass`; an error logged and re-raised
  (double reporting); a swallowed error with no comment saying why.
- `HTTPException` raised from a service; an error body built in a router.
- A status code that lies (200 on failure, 500 on a client error).

## Security and logging
- A secret, token, password, email or full body in a log line, an error
  message or a response.
- Auth checked by role but not by resource ownership (IDOR).
- `docs_url` left on in production; CORS `allow_origins=["*"]` with
  credentials.

## Tests
- A bug fix without a reproducing test.
- A test with `time.sleep`, a real clock, network, or a patched module
  where a dependency override would do.
- A test that cannot fail (asserts on its own fixture).
- `@pytest.mark.asyncio` added (mode is auto); an `event_loop` fixture.

## Hygiene
- `# noqa` or `# type: ignore` added without a code and a reason; a ruff
  rule disabled; a dependency added unasked; `uv.lock` edited by hand or
  not updated with `pyproject.toml`.
- A package named `utils`; a public function without a docstring.
- Em dash in a comment or doc.
