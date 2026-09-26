---
name: api-versioning
description: 'Versions and retires API endpoints: Deprecation and Sunset headers, consumer inventory, breaking-change diff, contract tests, log-gated removal. Use when asked to "deprecate an endpoint", "version the API" or "sunset".'
argument-hint: "strategy | deprecate <METHOD /path> [--sunset YYYY-MM-DD] | diff [<old spec>] | remove <METHOD /path> [--days 30] | contracts"
allowed-tools: Read, Write, Edit, Grep, Glob, Skill, Bash(ls:*), Bash(mkdir -p:*), Bash(git show:*), Bash(git tag -l:*), Bash(git log:*), Bash(git diff:*), Bash(oasdiff:*), Bash(grep -c:*), Bash(zgrep:*), Bash(make check:*), Bash(go test:*), Bash(pnpm exec vitest:*), Bash(uv run pytest:*)
---

# api-versioning

A public endpoint is a promise with a date on it. This skill puts the
date on, tells every consumer, proves nobody is left, and only then
removes the code.

Not this: `openapi-spec` writes and checks the contract itself; this
skill manages how it changes over time. `release` cuts the version.

## Inputs

- Mode: `$1`; if absent, `strategy` when no `docs/api/API_LIFECYCLE.md`
  exists, else `diff`.
- Spec: `api/openapi.yaml`; if absent, the routes grepped from the
  router files stand in, with "spec: none, routes from code" in the
  report and `diff` limited to path and method changes.
- Old spec for `diff`: `$2`, else `git show <last tag>:api/openapi.yaml`
  into `.scratch/api/old.yaml`; no tag: the base branch's copy; neither:
  stop with "no earlier spec to diff against".
- Consumers: `docs/api/API_LIFECYCLE.md` consumer table; if absent,
  built from `User-Agent` and API key names in the logs (Inputs below,
  matched with the step 4 pattern rules)
  and from `docs/integrations/`; none: one question, then "consumers:
  unknown" stays in the report until answered.
- Logs for the removal gate: `--log <path or glob>`; else every file
  under `logs/` (recursively, rotated and gzipped ones included) and
  `.scratch/logs/`, preferring the API gateway's over the service's own;
  else the query for the log platform is printed for the engineer to run
  and paste the count.
- Diff tool: `oasdiff` on `PATH`; absent: the manual checklist in
  `references/breaking-changes.md`, every item ticked by reading both
  specs, marked "manual".
- Contract test tool: Pact when `pact` config exists; else a schema
  snapshot under `tests/contracts/<consumer>/`.
- Templates: `templates/API_LIFECYCLE.md`, `templates/deprecation-notice.md`
  (to `docs/api/deprecations/<method>-<path-kebab>.md`).

## Steps

1. `strategy`: the `tech-decision` protocol with three options: URL
   (`/v2/`; visible, cacheable, two codebases to keep), header
   (`Accept: application/vnd.<name>.v2+json`; one URL, harder to test
   by hand), or none with additive-only rules (add fields and endpoints,
   never remove or retype, deprecate instead). Recommend additive-only
   for an internal API and URL for a public one; record the ADR (Accepted
   only when the user chose, else Proposed); write
   `docs/api/API_LIFECYCLE.md` from the template with the policy:
   deprecation notice period (default 90 days), headers, consumer
   inventory, removal gate.
2. `deprecate <METHOD /path>`: add `deprecated: true` and
   `x-sunset` to the operation in the spec; add the middleware or
   handler lines that send `Deprecation: @<unix time>` and `Sunset:
   <HTTP date>` and `Link: <successor>; rel="successor-version"`; write
   the notice from `templates/deprecation-notice.md` naming the
   successor, the date and the migration steps; list the consumers to
   tell from the inventory. Print "consumers to notify: N". N=0 with an
   unknown inventory is not zero consumers; say "inventory unknown".
3. `diff`: `oasdiff breaking <old> api/openapi.yaml` when installed,
   else the manual checklist. Print "operations compared: N, breaking:
   B, non-breaking: C" and list every breaking change with the
   operation. N=0: stop with "0 operations in the spec". B>0 without a
   version bump or a deprecation for each is a failed check. Append each
   breaking change as a row in the Breaking-change log of
   `docs/api/API_LIFECYCLE.md` (date, operation, change, what the consumer
   does, the version or deprecation that covers it), so the log is the
   record, not the terminal.
4. `remove <METHOD /path> [--days N]`: the gate. Require a Sunset date
   in the past. Count requests to the operation in the logs over the
   last N days (default 30), with the total request count alongside.
   Build the pattern from one log line, not from the spec: a path
   template's `{id}` becomes `[^/?"]+`, a query string may follow the
   path, and a JSON log keeps method and path in separate fields
   (`"method":"GET","path":"/v1/x/[^/?"]+/y`). Before trusting a zero,
   run the same pattern shape against a live route and see it match.
   `zgrep -cE` reads plain and `.gz` files alike; list the files and
   the first and last timestamp each covers, so a window the logs do
   not reach is visible. For each consumer key or user agent that ever
   called the operation, print its last call: a caller whose calls
   recur (a monthly or quarterly job) is only ruled out by a window
   longer than its period. Print "removal gate: <op>, window N days,
   requests to op R, total requests T, last caller <key> <date>". Pass
   only when R=0 and T>0; T=0 means the logs did not cover the window
   and the gate fails with "no traffic observed at all; wrong logs". On
   pass, delete the operation from the spec and the handler, and the
   notice moves to Removed in API_LIFECYCLE.md. On fail, correct any
   inventory row the logs contradict.
5. `contracts`: per consumer, a contract test: Pact verification when
   configured; else a snapshot test that captures the response schema
   for each operation the consumer uses (from the inventory) into
   `tests/contracts/<consumer>/<op>.json` and fails when the live
   schema removes or retypes a field. Add a `contracts` job to the CI
   file calling `make test-contracts` (add the target). Print
   "contracts: N consumers, M operations snapshotted, passed M".
6. Print the contract for the mode.

## Output contract

```
## API lifecycle: <mode> (<url | header | additive-only>, ADR <id>)
Spec: api/openapi.yaml (N operations) | routes from code
Deprecate <op>: Sunset <date>, successor <op>, notice docs/api/deprecations/<file>, consumers to notify N
Diff: operations compared N, breaking B, non-breaking C   [<oasdiff | manual>]
  <BREAKING> <op>: <what changed>
Removal gate <op>: window N days, requests R, total T -> <pass | fail: reason>
Contracts: N consumers, M operations, passed M   CI job: contracts <added | present>
Not done: <list> | none
```

## Gotchas

- "Nobody uses it" measured on logs that do not include the API
  gateway measures nothing. The gate prints the total so an empty
  window is visible.
- A literal `"GET /v1/x/{id}` grep matches nothing in a JSON log or
  against real ids, and reads as zero consumers. That is why the
  pattern is proved on a live route first.
- Adding a required request field is breaking. Adding an optional one
  is not. Removing a response field is breaking even when it was null.
- Narrowing an enum, tightening a pattern, lowering a max length:
  breaking for writers, invisible to a diff that only looks at
  presence. The checklist has them; `oasdiff` catches most.
- `Sunset` without `Deprecation` tells a client when, not that. Send
  both, plus the `Link` to the successor.
- A consumer inventory that lists teams instead of systems cannot be
  checked against a log. Inventory by API key or user agent.
- Deleting the handler and leaving the spec entry ships a 404 that
  looks like an outage. Spec and code go in the same commit.
- Contract snapshots that include example values churn on every run.
  Snapshot the schema, never the data.
