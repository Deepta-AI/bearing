# nextjs: traps in batch actions, read schemas and tenant tests

Read when you write a batch action, a read or write schema for legacy rows, or the another-tenant test.

- Batch actions: one ledger failure in `Promise.all` throws away the
  outcome of the rest. Settle each item, return which succeeded and which
  failed, expire the tags anyway, and keep the batch size bounded.
- A read schema stays loose for legacy rows; the write schema carries the
  current rules. A legacy row the write rules reject cannot be edited in
  place: say so on the page and refuse it in the action.
- Tests prove the boundary, not the mock: the "another tenant" test stubs
  the API (or `fetch`) to return a resource owned by someone else and
  asserts no write was sent. Stubbing your own ownership helper to say
  "not yours" tests nothing.
