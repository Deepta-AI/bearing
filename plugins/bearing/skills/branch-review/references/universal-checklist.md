# Universal review checklist

Applied to every diff, whatever the stack, by `branch-review` and by the
`reviewer` agent. For each item, construct the concrete failure (the
input or state that makes it wrong and what the user or operator sees)
or write "none found". A finding without a failure scenario is a
question, not a finding.

- Errors: an error path that returns without wrapping, logging or
  mapping; an empty catch; a bare `except`; a status code that lies;
  an error logged and then rethrown (log once, at the edge).
- Boundaries: input from a user, a queue or another service used
  without a schema or a size limit; output that includes secrets or
  PII; a boundary (API shape, schema, auth) changed without a matching
  test and doc.
- Authorisation: a check on role but not on resource ownership (IDOR);
  a check that runs only when an optional input (a header, a token, a
  flag) is present, so omitting it skips the check.
- Invariants and state: a limit checked per request that must hold
  across requests (a running total, a quota); an operation allowed from
  a state the domain forbids; an existing column, status or job that
  models the same concept and is left stale by the change.
- Side effects: a row committed before an external call and kept when
  the call fails; a retry that repeats a side effect with no idempotency
  key; a consumer that assumes a message arrives once and in order.
- Concurrency and resources: an unowned goroutine, task or timer; a
  handle not closed on every path; a lock held across I/O.
- Data: a query built by string concatenation; `SELECT *`; a migration
  without a Down, that locks a large table, or changes a column type in
  place; an N+1 in a loop; a missing index for a new filter; money or
  ids in floating point.
- Tests: a bug fix without a reproducing test; a test with a real
  clock, network or sleep; a test that cannot fail.
- Hygiene: a dependency added unasked; a lint rule, threshold or hook
  weakened; a suppression comment (`eslint-disable`, `nolint`, `noqa`,
  `@Suppress`, `swiftlint:disable`); `any`; a skipped test; generated
  code edited by hand; a secret, token or personal path in the diff.
- Commits: Conventional, carrying the task id, no AI attribution
  trailer.
- Prose: an em dash in a comment, doc or UI string.

Severity: Critical (data loss, security, outage), High (wrong behaviour
on a normal path), Medium (wrong behaviour on an edge path, missing test
for a bug fix), Low (clarity, naming, dead code). Style that a formatter
or linter decides is never a finding.
