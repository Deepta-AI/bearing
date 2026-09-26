# API style

The rules every HTTP API on this standard follows. `openapi-spec` checks a spec
against them; `branch-review` checks handlers against them.

## Naming

- Paths are plural nouns in kebab-case: `/purchase-orders/{id}/lines`.
  No verbs in paths; an action that is not CRUD is a sub-resource
  (`POST /invoices/{id}/send`).
- JSON fields are `snake_case`. Ids are strings (uuid v7 when they
  leave the system). Timestamps are RFC 3339 in UTC with the `Z`.
- Money is `<name>_minor` integer plus `currency` (ISO 4217). Never a
  float.
- `operationId` is `verbResource` in camelCase and unique.

## Errors

- One envelope for every 4xx and 5xx:

```json
{ "error": { "code": "validation_failed", "message": "amount_minor must be positive",
             "details": [ { "field": "amount_minor", "reason": "min 1" } ],
             "request_id": "req_01J9Z6" } }
```

- `code` is a stable snake_case string the client can switch on;
  `message` is for humans and may change; `details` is optional and
  structured; `request_id` is always present and matches the
  `X-Request-Id` header and the server log line.
- Status map: 400 malformed, 401 no or bad token, 403 authenticated but
  not allowed on this record, 404 not found or not visible to this
  caller (never reveal which), 409 idempotency or state conflict, 422
  valid shape but invalid content, 429 rate limited, 500 unexpected.
- Never leak stack traces, SQL, or internal hostnames in `message`.

## Pagination

- Cursor pagination on every list: `?cursor=&limit=` in, `page:
  { next_cursor, has_more }` out. `limit` is capped (100 by default) and
  the cap is in the spec. Offset pagination only for admin tables under
  10k rows, and the spec says so.
- The cursor is opaque to the client (base64 of the sort key and id).
  Sorting is fixed per endpoint or chosen with `sort=-created_at`.

## Filtering

- `filter[field]=value` for equality, `filter[field][gte]=` for ranges.
  Every filterable field is listed in the spec with its type; a filter
  not in the spec is a 400. Each one has an index decision recorded in
  the data model.

## Idempotency

- Every POST that creates or charges requires `Idempotency-Key` (a
  client UUID). The server stores key, request hash and response for 24
  hours; same key and same body replays the stored response; same key
  and a different body is 409 `idempotency_conflict`.
- PUT and DELETE are idempotent by definition; PATCH must be documented
  as such or not offered.

## Versioning

- The path carries the major (`/api/v1`). Behaviour changes inside a
  major are date versions in `X-API-Version: 2026-09-01`; the server
  default is the newest and is stated in the spec description.
- Breaking means: a removed path or field, a new required field, a
  narrowed type or enum, a changed status code. `oasdiff breaking`
  against the last tag is the gate.
- Removal is `deprecated: true`, a `Sunset` header with the date, and a
  minimum of 90 days.

## Rate limits

- Every response carries `X-RateLimit-Limit`, `X-RateLimit-Remaining`
  and `X-RateLimit-Reset` (epoch seconds). A 429 carries `Retry-After`.
- Limits are per token and per IP, and both numbers are in the spec.

## Security

- Bearer JWT on every operation unless the operation lists
  `security: []` with a comment saying why it is public.
- Authorisation is per record: a resource the caller may not see is a
  404, not a 403, so existence does not leak.
- Request bodies are capped (1 MB default); uploads use a signed URL.
- `Content-Type` is checked; anything but `application/json` on a JSON
  route is 415.

## Documentation

- The spec lives at `api/openapi.yaml` and is linted in CI with
  `npx @redocly/cli@2.54.3 lint`. Docs are served from the running service at
  `/docs` (Redoc or Scalar) and `docs/api/README.md` says how.
- Every schema has an `example`. Every operation has `x-story-ids`.

## Conventions summary

The numbered list below is what `scripts/api_doc.py` copies into
`docs/api/API.md` under Conventions, one line each, in the form
`N. <rule>. Why: <reason>.` Keep it in step with the sections above; a
project adds its own with `x-conventions` in the spec.

1. Paths are plural kebab-case nouns and a non-CRUD action is a sub-resource (`POST /invoices/{id}/send`). Why: a client can guess the URL of a resource it has not seen, and verbs in paths multiply without limit.
2. JSON fields are snake_case, ids are strings, timestamps are RFC 3339 UTC with `Z`. Why: one casing and one clock remove a whole class of client parsing bugs.
3. Money is an integer `<name>_minor` plus an ISO 4217 `currency`. Why: floats cannot hold 0.10 exactly, and an amount without a currency is ambiguous.
4. Every 4xx and 5xx returns the one error envelope with a stable `code` and a `request_id`. Why: clients switch on `code`, not on English, and support finds the log line from `request_id`.
5. A record the caller may not see is 404, never 403. Why: a 403 confirms the record exists, which turns a guessed id into an oracle.
6. Every list is cursor-paginated with a capped `limit`. Why: offsets skip or repeat rows while data changes, and an uncapped page is a denial of service.
7. Every POST that creates or charges requires `Idempotency-Key`; the same key and body replays the first response for 24 hours. Why: mobile networks retry, and a retry must not create a second record or a second charge.
8. The path carries the major version and `X-API-Version` carries dated changes inside it. Why: installed clients cannot be forced to upgrade, so breaking changes need a new major and everything else a date.
9. Removal is `deprecated: true` plus a `Sunset` header and at least 90 days. Why: a removed field breaks a client nobody told, and oasdiff can only warn about what is still in the spec.
10. Every response carries the rate-limit headers and a 429 carries `Retry-After`. Why: a client that can see its budget backs off before it is throttled.
