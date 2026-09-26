# MCP design rules

## Server boundary

One server per bounded context: `orders`, `documents`, `calendar`. The
server owns the auth to its backend; the model never sees a backend
credential. A server that needs two backends is two servers unless one
tool genuinely joins them.

## Tool naming

- `verb_object`, snake_case, under 40 characters: `list_orders`,
  `get_invoice`, `create_ticket`, `search_documents`.
- One verb per tool. `get_or_create` is two tools.
- The client namespaces as `<server>__<tool>`; the server does not
  prefix its own name.
- Read tools outnumber write tools. If not, the boundary is wrong.

## Description quality

The description is the model's only manual. Four sentences:

1. What it returns, with units and the maximum count.
2. When to use it.
3. When not to use it, and which tool to use instead.
4. Errors it returns by `code` (`not_found`, `invalid_range`,
   `rate_limited`).

Every schema property has a `description`, a type, and a bound (max
length, min and max, enum, pattern). Optional fields have defaults in
the description.

## Pagination

List tools take `cursor` (opaque string, optional) and `limit`
(1 to N, default N) and return `{items, next_cursor}`. Never return
more than the limit; never return "all". Say the maximum in the
description so the model knows to page.

## Idempotency

Every mutating tool takes an `idempotency_key` (string, required),
the same for every retry of one intent. The server claims it with an
insert guarded by a unique constraint before the effect (a unique
violation returns the stored result, or an in-progress error), stores
the result with it, and keeps it longer than the longest path that can
resend the call. Retries by the model or the client become safe.

## Tool annotations

Every tool sets `title` and all four hints, derived from its tier. The
host auto-approves `readOnlyHint` tools and asks before
`destructiveHint` ones; an unset hint means the worst case.

| Tier | `readOnlyHint` | `destructiveHint` | `idempotentHint` | `openWorldHint` |
| --- | --- | --- | --- | --- |
| `read` | true | false | true | true only when it reads outside the server's own backend (web, third-party API) |
| `write` | false | false | true (idempotency key) | as above |
| `irreversible` | false | true | true when it takes an idempotency key, else false | as above |

A tool whose hints disagree with its tier (a `read` tool that is not
`readOnlyHint`, a delete that is not `destructiveHint`) is a finding.
Hints come from the server and are not a trust boundary: the client's
tier mapping still decides.

## Errors

Structured, never a bare string:

```json
{ "code": "not_found", "message": "order o_123 does not exist", "retryable": false }
```

Returned as a tool result with `isError: true` (TypeScript) or the
error content the SDK maps. A stack trace is never in the message.

## Secrets

- Backend credentials from the environment on the server.
- No token, key, password, session id, full card number, full account
  number or Aadhaar in any tool output or resource; redact to the last
  four characters.
- HTTP transport requires auth: a bearer token checked per request, or
  OAuth for user-scoped servers. stdio inherits the local user's trust.

## Resources and prompts

- Resources are for data the model should read as context, not act on:
  `resource://orders/o_123` returns the order document. Templates list
  what exists. Do not put a mutating action behind a resource.
- Prompts are recipes the client offers the user: "triage this ticket"
  with arguments. Keep them in the prompt registry (`prompt-registry`) and
  expose them through the server; do not write a second copy.

## Limits and logging

- Per-tool timeout (default 30 s), per-caller rate limit (default 60
  calls per minute), max payload sizes.
- Every call logs `request_id`, `tool`, `caller`, `outcome`, `ms`, and
  never the arguments at info level (they may hold PII).
- Health: an HTTP server exposes `/healthz`; a stdio server answers
  `ping`.

## Client side

- Discover, then map. A discovered tool is not callable until it has a
  tier in `mcp/tiers.yaml`; unmapped means `irreversible`, reported.
- Reconnect with exponential backoff (1 s, 2 s, 4 s, cap 30 s); after
  the cap, mark the server unavailable and let the agent continue
  without its tools rather than hang.
- Handle `notifications/tools/list_changed` by re-listing and applying
  the mapping again. Log every change.
- Cache the tool list per session; do not call `list_tools` per turn.

## Testing

- Server: a protocol-level test per tool through a client session over
  stdio, three cases each (valid, invalid input, not found), plus an
  annotation check per listed tool: all four hints set and matching the
  tier. A tool without annotations fails.
- Client: a fake server in the test process with two tools; assert the
  mapping, the restart, the list change and the timeout.
- Counts printed: tools exposed, tools tested, mapped, unmapped. Zero
  tools fails the suite.
