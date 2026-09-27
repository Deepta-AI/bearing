# Python review checklist

For each item, either find the concrete failure or write "none found".

Before a finding goes in the review, prove it: read the called library's
actual default, run a probe test in a scratch folder (never in the
repository under review), or compute the number. A confident wrong
finding costs more trust than a missed Low. Read the repository's own
docs (provider contracts, ADRs, README) before the diff: the worst bugs
are code that is internally consistent and contradicts a document.

## Async correctness
- A blocking call in an async path: `requests`, `time.sleep`, a sync DB
  driver, `open()` on a large file, CPU work over a few milliseconds.
- A coroutine called without `await` (the result is a never-run coroutine
  object; ruff RUF006 and mypy catch some, the reviewer catches the rest).
- `asyncio.create_task` with no owner, no reference kept, no error handling.
- An `AsyncSession` stored on `app.state`, a module, or a class attribute
  and used across requests.
- A network call with no effective timeout. Know the defaults before
  claiming one is missing: `requests` and `urllib` have none (a finding),
  `httpx` has 5 s per phase (only a finding if 5 s is wrong for the
  caller), `aiohttp` has 5 minutes total. The bigger issue is usually
  an outbound call on the request path or in an unowned task.
- Worst-case latency against the caller's deadline: add up retries,
  sleeps, busy timeouts (`sqlite3.connect(timeout=5)` waits up to 5 s per
  attempt) and outbound timeouts, and compare with the documented
  deadline. A handler that can outlast it is retried by the caller while
  its first attempt still commits.
- A retry that catches a broad family (`sqlite3.OperationalError` covers
  syntax errors and missing columns as well as "database is locked";
  `httpx.HTTPError` covers 4xx after `raise_for_status`): only transient
  errors are retried.

## Database
- A relationship without `lazy="raise"`; a lazy load inside a loop (N+1).
- `select(Model)` outside `app/db/repositories`; a raw SQL string built
  with f-strings or `%`; `text()` with interpolated values.
- An unbounded query: no `limit`, no `order_by` on a paginated list.
- Keyset paging on a nullable column: a row whose sort key is NULL fails
  every `(col, id) < (?, ?)` comparison, so it is skipped or, if it lands
  last on a page, breaks the cursor. Check the schema's nullability and
  the data, not a comment saying "NULL only while ...".
- A `commit()` inside a repository; a transaction opened in a router.
- A migration that cannot be re-run after a crash between applying it
  and recording it (`CREATE INDEX` without `IF NOT EXISTS` when the runner
  records the file after `executescript` has committed).
- An Alembic migration with an empty or missing `downgrade`, an
  autogenerate diff committed unread, a new filter without an index
  decision, a lock held on a hot table.

## Pydantic and typing
- A mutable default where it is shared: a function argument
  (`def f(x=[])`) or a dataclass field without `default_factory`. On a
  Pydantic v2 model `items: list[str] = []` is safe (defaults are copied);
  do not report it.
- `Model.model_validate(...)` or `json.loads` inside a handler: its
  `ValidationError` or `JSONDecodeError` is not FastAPI's
  `RequestValidationError`, so a bad body is a 500, not a 422, unless it
  is caught and mapped.
- A secret typed `str` instead of `SecretStr`: it prints in every repr,
  traceback and settings dump.
- A request model without `extra="forbid"`; a route without
  `response_model`; a `dict` returned past the router.
- `X | None` accepted and then used as `X` without a `None` branch.
- `Any`, an untyped `def`, `# type: ignore` without a code, `cast` used to
  silence rather than to narrow.

## Webhooks and other inbound events
- The signature is verified over the raw body bytes (`await
  request.body()`), before any parsing or logging, with
  `hmac.compare_digest`. Re-serialised JSON never matches the sender's
  bytes; a test that signs `json.dumps` output proves nothing.
- A missing secret fails closed: settings refuse to start, never an
  `if not secret: return True` bypass. An empty HMAC key is a key anyone
  can use.
- Delivery is at least once: the event id is recorded in the same
  transaction as its effect, so a redelivery is a no-op.
- Read the sender's contract for routing and semantics: one URL per
  account or per event type; whether an amount is this event's delta or a
  running total; whether events can arrive out of order. An absolute,
  monotonic update (`SET x = max(x, ?)`) survives both redelivery and
  reordering; `x = x + ?` survives neither.
- Anything answered 2xx is never redelivered: an event type answered
  "ignored" is lost for good. Transient failures answer 5xx; permanent
  bad input answers 4xx.
- Amount, currency and target are checked against the record (positive,
  same currency, not above what was paid, matched row count read).

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
