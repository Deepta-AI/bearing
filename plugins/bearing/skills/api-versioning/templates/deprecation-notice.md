# Deprecation: <METHOD /path>

<!-- Template guidance: every section below carries a comment saying what goes
     there (What), what a strong entry has (Good) and a one-line example
     (Example). Delete each comment when you fill its section. This notice
     goes to every consumer in the inventory on the day the headers go live;
     it names the successor, the date and the migration steps. Written to
     docs/api/deprecations/<method>-<path-kebab>.md. -->

| Field | Value |
| --- | --- |
| Deprecated on | <YYYY-MM-DD> |
| Sunset (removal not before) | <YYYY-MM-DD> (<N> days notice) |
| Successor | `<METHOD /path>` |
| Headers sent | `Deprecation: @<unix>`, `Sunset: <HTTP date>`, `Link: <successor>; rel="successor-version"` |
| Consumers affected | <list from the inventory> |
| Contact | <team or email> |

## Why

<!-- What: one paragraph on what changed and why the old shape cannot stay.
     Good: a reason the consumer can check (a field that was always null, a
     security finding id, a model change), not "to improve the API".
     Example: "GET /v1/orders returns every order unpaged; at 40,000 orders
     for the largest merchant it times out at 30 s. v2 pages by cursor." -->

<one paragraph: what changed and why the old shape cannot stay>

## What changes for you

<!-- What: the old request or response shape beside the new one, one row
     per difference.
     Good: covers every removed, renamed or retyped field, including
     response fields that were null; shapes are literal, not described.
     Example: "| `{\"orders\": [...]}` | `{\"data\": [...], \"next_cursor\":
     \"c_81f\"}` |" -->

| Old | New |
| --- | --- |
| `<request or response shape>` | `<shape>` |

## Migration steps

<!-- What: numbered steps a consumer follows to move to the successor.
     Good: the first step has an example request, and the last step says
     how the consumer can verify they are done (a header, a field, a
     sandbox call).
     Example: "1. Call `GET /v2/orders?limit=100` and follow `next_cursor`
     until it is null." -->

1. <step with an example request>
2. <step>
3. Confirm by <how the consumer can verify: a header, a field, a sandbox>.

## Timeline

<!-- What: the dated events from notice to removal.
     Good: Sunset is at least the policy's notice period after the notice
     date; removal comes only after Sunset has passed and the removal gate
     has passed.
     Example: "| 2026-09-29 | Sunset; removal gate measured over 30 days of
     gateway logs |" -->

| Date | Event |
| --- | --- |
| <date> | notice sent, headers live |
| <date> | reminder |
| <date> | Sunset; removal gate measured |
| <date> | removed |
