# Go review checklist

For each item, either find the concrete failure or write "none found".

## Correctness
- A handler writes an error response and continues without `return`.
- An error is discarded (`_ = f()`, `err` shadowed by `:=` in an inner scope
  and never checked), or logged and then returned (logged twice up the
  chain).
- `context.TODO()` or `Background()` outside `main` and tests; a context not
  passed to a DB or HTTP call.
- A goroutine with no owner, no stop signal, or writing to a closed channel.
- A loop variable captured by a goroutine or closure, only when `go.mod`
  says `go 1.21` or lower; from 1.22 each iteration has its own variable.
- A pointer that can be nil stored in an interface, then checked with
  `!= nil` (typed nil: the check passes and the call panics).
- A goroutine started from a handler: its panic kills the process, and
  `r.Context()` is already cancelled when it runs.
- A map read and written from different goroutines without a lock.
- `defer` inside a loop holding a resource until the function ends.
- Money: overflow, a float, or integer division that drops the minor unit
  against a documented format.
- A state change done as read, check, then unconditional write: two
  requests both pass the check.

## HTTP
- Missing `DisallowUnknownFields`, missing body size limit, missing timeouts.
- Auth checked by role but not by resource ownership (IDOR); a lookup or
  write through an unscoped repository method.
- A numeric parameter without the documented lower and upper bound.
- A streamed body (CSV, NDJSON) whose write errors are unchecked: the 200 is
  already sent, so a failure is a silently truncated file.
- A status code that lies (200 on failure, 500 on a client error), or an
  error mapper that disagrees with the documented error table.
- A nil slice encoded where the contract promises an array: it goes out
  as `null`, not `[]`.
- Sensitive data in a log line or error message returned to the client.

## Database
- A tenant filter not ANDed with the whole WHERE (`t = $1 AND a OR b`
  leaks every tenant's rows matching `b`).
- An identifier (ORDER BY column, direction) taken from input without an
  allowlist of fixed clauses; an allowlisted clause naming a missing column
  or the wrong direction.
- `SELECT *`; a query built by string concatenation; a missing index for a
  new filter; a migration without a Down; a transaction opened in a
  repository; a long migration holding a lock on a hot table.
- A migration that drops a constraint by a name an earlier migration
  already replaced, loses a rule the old constraint enforced, or has a Down
  that fails once the new code has written rows.
- `rows.Err()` not checked after the loop; `pgx.Rows` not closed on every path; `QueryRow` result not checked for
  `pgx.ErrNoRows`.
- N+1 query in a loop.

## Tests
- A bug fix without a reproducing test.
- A test with `time.Sleep` or a real clock outside a `synctest.Test`
  bubble, or with network.
- A test that cannot fail (asserts on its own fixture), or a fake that
  re-implements the filter the SQL gets wrong, so the SQL is never tested.
- A test that asserts the wrong value the contract rules out.

## Hygiene
- `//nolint` added; a lint rule disabled; a dependency added unasked.
- Generated code (`sqlc`, `.pb.go`) edited by hand.
- An exported identifier without a doc comment; a package named `util`.
- Em dash in a comment or doc.
