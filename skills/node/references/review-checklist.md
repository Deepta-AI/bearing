# Node review checklist

For each item, either find the concrete failure or write "none found".

## Async correctness
- A promise not awaited or returned: a floating `reply.send`, a forgotten
  `await` on a repository call, a `void` without a comment saying why.
- An `async` handler that also calls `done()` or returns after `reply.send`
  without `return reply`.
- A `setTimeout`, `setInterval` or event listener with no owner and no
  clear on shutdown; an unhandled rejection path.
- An outbound `fetch` or client call with no timeout and no `AbortSignal`.
- `process.exit` outside `src/server.ts`.

## HTTP and validation
- A route without a `schema`; a body, param or query read without a Zod
  parse; a response without a schema for its success status.
- `process.env` read outside `src/config.ts`; a secret with a default.
- Auth checked by role but not by resource ownership (IDOR).
- A status code that lies (200 on failure, 500 on a client error); an
  error body built in a route instead of thrown as `AppError`.
- A missing body size limit or `trustProxy` turned on without a reason.

## Database
- `db.select` or `db.insert` outside the repository layer; `sql.raw` or a
  template string with an interpolated value.
- An unbounded query: no `limit`, no `orderBy` on a paginated list; an N+1
  in a loop.
- A transaction opened in a repository or a route; a transaction spanning
  an outbound call.
- A migration edited by hand, a `drizzle/meta` file changed without
  `drizzle-kit generate`, a new filter without an index decision, a
  destructive change without an expand-and-contract plan.

## Types
- `any`, a non-null assertion, an `as` cast that hides a real gap, a
  `@ts-expect-error` without a reason.
- An interface that duplicates a Zod schema instead of `z.infer`.
- `X | undefined` used as `X` without a branch.

## Logging and security
- `console.log`; a log line with a token, password, cookie, email or full
  body; an error message that leaks internals to the client.
- A request id missing from a log line because `app.log` was used inside a
  request instead of `request.log`.
- A dependency added unasked; a `pnpm audit` finding silenced with an
  override.

## Tests
- A bug fix without a reproducing test.
- A unit test that opens a database or network connection; a test with a
  real timer or a sleep.
- A test that cannot fail (asserts on its own fixture); a mocked module
  where an injected dependency would do.
- A new route without an `inject` test for the success and the error path.

## Hygiene
- `eslint-disable` added; a lint rule loosened; a coverage threshold
  lowered; `pnpm-lock.yaml` edited by hand or not updated with
  `package.json`.
- A module named `utils`; an exported function without a doc comment.
- Em dash in a comment or doc.
