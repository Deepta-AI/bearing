# Test data: builders, reference data, seeds and cleanup

Three kinds of data, kept apart, so every test can run alone, in any order,
in parallel and twice in a row with the same result:

| Kind | What it is | Where it lives | Who writes it | Tests may |
| --- | --- | --- | --- | --- |
| Reference | Lookups the product needs to run: currencies, roles, plan tiers, country codes | A migration (or `db/reference/*.sql` loaded by `make migrate`), versioned with the schema | Migrations only | Read it; never write it |
| Scenario | The rows one test is about: this user, this invoice | Built in the test by a builder below, unique per run | The test's fixture | Create it, then leave nothing behind |
| Demo seed | A believable dataset for local development and demos | `make seed`, idempotent (upserts by natural key), never loaded in a test run | `make seed` | Nothing: a test that needs a seed row is depending on luck |

A builder makes one valid object with every field filled, and lets a test
override only what it is about. Values come from the test-case row's data
column; uniqueness comes from a run id, never from `Math.random`. One
builder per aggregate, beside the fixtures.

## TypeScript (Playwright, vitest, jest-expo)

```ts
// e2e/fixtures/builders.ts
let seq = 0;
const runId = process.env.RUN_ID ?? `local-${Date.now()}`;

export function aUser(overrides: Partial<User> = {}): User {
  seq += 1;
  return {
    id: `u-${runId}-${seq}`,
    email: `user-${runId}-${seq}@example.test`,
    password: "correct-horse",
    role: "member",
    createdAt: "2026-01-01T00:00:00Z", // fixed; the clock is injected
    ...overrides,
  };
}
// TC-0004: aUser({ email: "a".repeat(243) + "@example.test" })
```

## Python (pytest)

```python
# tests/builders.py
import itertools
_seq = itertools.count(1)

def a_user(**overrides) -> dict:
    n = next(_seq)
    base = {"email": f"user-{RUN_ID}-{n}@example.test", "password": "correct-horse", "role": "member"}
    return {**base, **overrides}
```

## Go

```go
// internal/testutil/builders.go
func AUser(t *testing.T, opts ...func(*User)) User {
    t.Helper()
    u := User{Email: fmt.Sprintf("user-%s-%d@example.test", runID, next()), Role: "member"}
    for _, o := range opts { o(&u) }
    return u
}
func WithEmail(e string) func(*User) { return func(u *User) { u.Email = e } }
```

## Kotlin (Android)

```kotlin
fun aUser(email: String = "user-$runId-${next()}@example.test", role: Role = Role.MEMBER) = User(email = email, role = role)
```

## Swift (iOS)

```swift
extension User {
    static func a(email: String = "user-\(runId)-\(next())@example.test", role: Role = .member) -> User { User(email: email, role: role) }
}
```

## Rules

- Every field has a valid default. A test that only cares about `email`
  passes only `email`.
- The boundary values in the test-case table are written into the test,
  not into the builder default.
- Dates and ids are deterministic. Inject the clock; seed from the run id.
- A builder never touches the network or the database. Persisting is the
  fixture's job.

## Persisting and cleaning up

- Against a local or CI database: each test runs in a transaction that is
  rolled back (Go `pgx.Tx`, pytest's rolled-back session, a Node `tx` with
  `rollback()`). Nothing to clean, and parallel tests cannot see each other.
- Across a real HTTP boundary (the API runs in its own process, or e2e runs
  against a deployed qa): the fixture creates through the API, records what
  it created, and deletes it in teardown, newest first. Every id and every
  unique field carries the run id (`RUN_ID`, the CI pipeline id or
  `local-<timestamp>`), so a crashed run leaves rows a sweeper can find.
- The sweeper: `make test-data-sweep` deletes rows whose unique fields start
  with a run-id prefix older than 24 hours, and prints the count. It runs
  nightly against qa, never against production, and refuses a
  `DATABASE_URL` or `BASE_URL` that names production.
- Never truncate a shared table to "start clean": another run is using it.
- A test never assumes an empty table or a count. It asserts on the rows it
  made (`WHERE email LIKE 'user-<run id>-%'`), not on "there are 3 invoices".

## Keeping it true over time

- Builders are typed against the domain (`Partial<User>`, a dataclass, the
  Go struct), so a new required field breaks the builder at the type check,
  not a test at run time. Add the field with a valid default in the same
  change.
- One test per builder proves its default is valid: build it, run it
  through the same validator the API uses (the Zod schema, the Pydantic
  model, the Go `Validate()`), expect no error. A schema change that makes
  the default invalid fails there, with the builder's name, first.
- Reference data changes only through a migration, with a test that reads
  the new value. Never edit it in a fixture.
- When a test fails with a 4xx from a fixture or a unique constraint,
  `test-heal` classes it test data and fixes the builder or the
  fixture, never the order of the tests.
