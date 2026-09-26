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
- A loop variable captured by a goroutine or closure (Go < 1.22 semantics).
- A map read and written from different goroutines without a lock.
- `defer` inside a loop holding a resource until the function ends.
- Integer overflow or wrong type conversion on money or ids.

## HTTP
- Missing `DisallowUnknownFields`, missing body size limit, missing timeouts.
- Auth checked by role but not by resource ownership (IDOR).
- A status code that lies (200 on failure, 500 on a client error).
- A nil slice encoded where the contract promises an array: it goes out
  as `null`, not `[]`.
- Sensitive data in a log line or error message returned to the client.

## Database
- `SELECT *`; a query built by string concatenation; a missing index for a
  new filter; a migration without a Down; a transaction opened in a
  repository; a long migration holding a lock on a hot table.
- `pgx.Rows` not closed on every path; `QueryRow` result not checked for
  `pgx.ErrNoRows`.
- N+1 query in a loop.

## Tests
- A bug fix without a reproducing test.
- A test with `time.Sleep` or a real clock outside a `synctest.Test`
  bubble, or with network.
- A test that cannot fail (asserts on its own fixture).

## Hygiene
- `//nolint` added; a lint rule disabled; a dependency added unasked.
- Generated code (`sqlc`, `.pb.go`) edited by hand.
- An exported identifier without a doc comment; a package named `util`.
- Em dash in a comment or doc.
