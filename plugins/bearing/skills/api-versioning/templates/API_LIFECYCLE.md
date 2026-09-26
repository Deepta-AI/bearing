# API lifecycle

<!-- Template guidance: every section below carries a comment saying what goes
     there (What), what a strong entry has (Good) and a one-line example
     (Example). Delete each comment when you fill its section. This is the
     record of how the API changes over time: the versioning strategy, who
     consumes what, what is deprecated and when it may go. Consumers, API
     owners and whoever runs the removal gate read it. -->

Strategy: <url versioning `/vN/` | header `Accept: application/vnd.<name>.vN+json` | additive-only> (ADR <id>).
Spec: `api/openapi.yaml`. Contract tests: `make test-contracts` (CI job `contracts`).
Last reviewed: <YYYY-MM-DD> by <name>.

## Policy

<!-- What: the rules every change follows: what ships any time, how a
     breaking change is handled, the notice period, the headers and the
     removal gate.
     Good: the notice period is a number of days (default 90) and the gate
     is countable: zero requests over N days of logs with non-zero total
     traffic. Adding a required request field or removing a response field
     is breaking; say so rather than "no breaking changes".
     Example: "Deprecation notice period: 180 days minimum (public partner
     API, ADR-0007)." -->

- Additive changes ship any time: new operations, optional fields, new response fields, widened enums.
- A breaking change gets a new version or a deprecation of the old operation; never an in-place change.
- Deprecation notice period: <90> days minimum. Headers on every response of a deprecated operation: `Deprecation: @<unix>`, `Sunset: <HTTP date>`, `Link: <successor>; rel="successor-version"`.
- Removal gate: zero requests to the operation over <30> days of logs that show non-zero total traffic, Sunset in the past, every listed consumer notified.
- Notices live in `docs/api/deprecations/` and are sent to every consumer in the inventory on the day the headers go live.

## Consumer inventory

<!-- What: one row per consuming system: how it shows up in the logs, the
     operations it calls, a contact and its contract test.
     Good: inventory systems by API key or user agent, never by team, or the
     removal gate cannot check it against a log. An unknown inventory says
     "consumers: unknown", which is not zero consumers.
     Example: "| mobile-app | `User-Agent: OrdersApp/4.*` | `GET /v1/orders`,
     `POST /v1/orders` | mobile@example.com | `tests/contracts/mobile-app/` |" -->

| Consumer (system) | Identified in logs by | Operations used | Contact | Contract test |
| --- | --- | --- | --- | --- |
| <name> | `User-Agent: <ua>` / API key `<name>` | `GET /orders`, ... | <team or email> | `tests/contracts/<consumer>/` |

## Deprecated operations

<!-- What: one row per operation marked deprecated in the spec and still
     served: dates, successor, notice file, notification count, status.
     Good: Sunset is at least the notice period after the deprecation date;
     "Consumers notified" is N of N from the inventory, and every row has a
     notice file under docs/api/deprecations/.
     Example: "| `GET /v1/orders` | 2026-07-01 | 2026-09-29 | `GET /v2/orders`
     | `docs/api/deprecations/get-v1-orders.md` | 3 of 3 | deprecated |" -->

| Operation | Deprecated on | Sunset | Successor | Notice | Consumers notified | Status |
| --- | --- | --- | --- | --- | --- | --- |
| `GET /v1/orders` | <date> | <date> | `GET /v2/orders` | `docs/api/deprecations/get-v1-orders.md` | N of N | deprecated |

## Removed operations

<!-- What: one row per operation removed after passing the removal gate.
     Good: the gate evidence is the numbers the gate printed (window in
     days, requests to the operation, total requests) with R = 0 and T > 0,
     and the commit removed the spec entry and the handler together.
     Example row: "| `GET /v1/orders` | 2026-10-02 | 30 days, 0 requests,
     4,812,330 total | 9f3c2ab |" -->

| Operation | Removed on | Gate evidence (window, requests, total) | Commit |
| --- | --- | --- | --- |

## Breaking-change log

<!-- What: one row per diff run that compared two versions of the spec.
     Good: the refs are exact (tag or commit to commit), the breaking count
     comes from oasdiff or the manual checklist (say which), and every
     breaking change names the version bump or deprecation that handles it.
     Example row: "| 2026-08-14 | v2.3.0 to 4be91d0 (oasdiff) | 1: `status`
     enum narrowed on `GET /v2/orders` | deprecation, notice get-v2-orders.md |" -->

| Date | Spec diff (old ref to new) | Breaking | Handled by |
| --- | --- | --- | --- |
