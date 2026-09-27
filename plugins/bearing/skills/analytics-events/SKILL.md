---
name: analytics-events
description: 'Designs the analytics event sheet, wires the analytics SDK behind one typed module and audits code against the sheet. Use when asked to "track this feature", "add an event", "set up analytics" or "audit tracking".'
argument-hint: "app | feature <name> | event <object_verb> | audit [--platform web|rn|android|ios|backend]"
allowed-tools: Read, Write, Edit, Grep, Glob, Skill, Bash(git diff:*), Bash(git status:*), Bash(git log:*), Bash(make:*), Bash(go test:*), Bash(node --test:*), Bash(node --no-warnings --test:*), Bash(npm test:*), Bash(pnpm test:*), Bash(uv run pytest:*), Bash(./gradlew test:*), Bash(swift test:*)
---

# analytics-events

Events are designed before they are emitted, and the code emits the sheet.
The numbers analysts get are only as good as three things a generalist
skips: every place the thing can become true, the consent and identity
footing of each funnel step, and what the payload carries besides the
properties you typed.

## Inputs

- scope: `$ARGUMENTS`; if absent, infer it from the request (a brief or
  feature named: `feature`; "check", "audit", "numbers look off":
  `audit`), else ask one question.
- journeys and stories: the brief the request names, else
  `docs/product/**` (backlog, PRD, feature briefs), else derived from the
  code: routes, screens and forms grouped by navigation; the sheet's
  story column then holds the route or screen name, marked "derived".
- platforms: from `package.json`, `build.gradle.kts`, `Package.swift`,
  `go.mod`, `pyproject.toml`; none: design only, the wiring waits.
- sheet and plan: `docs/analytics/EVENT_SHEET.md` and
  `docs/analytics/tracking-plan.md`; read every other file under
  `docs/analytics/` and the analytics ADRs too (collector contracts and
  later decisions override a stale sheet). If absent, created from
  `templates/EVENT_SHEET.md` and `templates/tracking-plan.md` (a
  repository `docs/templates/EVENT_SHEET.md` wins).
- vendor or collector: an accepted ADR; else the Decisions first protocol
  below; if deferred, a console destination behind the same interface.
- gate: `make check` when the Makefile has it; else the stack's test
  command (`node --test`, `npm test`, `go test ./...`, `uv run pytest`),
  and the report says which.

## Steps

**Decisions first.** Before building, run `tech-decision` for the key
analytics vendor, only when no accepted ADR, the request or the code
settles it. A key still awaiting an answer follows
${CLAUDE_PLUGIN_ROOT}/skills/tech-decision/references/decision-protocol.md.
Choices you make yourself (names, buckets, which layer) are recorded as
Proposed and listed in the report; never Accepted.

1. Scope: `app` (every journey), `feature <name>` (its brief or routes),
   `event <object_verb>` (one event), `audit` (step 6 only; change no
   code or doc unless asked).
2. Read the sheet, the plan, the analytics module on every side, and
   `references/event-design.md`. Note the context each module stamps
   (tenant, page path, platform, ids): it is part of every payload.
3. Design each event from the question it answers (write the analyst's
   query in one line; if you cannot, the event or a property is wrong):
   - `object_verb`, snake_case, past tense; one trigger at the moment the
     thing became true, in the layer that knows it (server for anything
     money, identity or state that a client could fake, lose or repeat).
   - Properties as `name: type`, enumerations spelled out, a source for
     each value. Amounts are integer minor units plus `currency`. Every
     event carries the join key the funnel needs (`invoice_id`,
     `order_id`) and the tenant.
   - Enumerations fed by a third party (failure codes, methods) get one
     catch-all value (`other`) and the mapping lives in code, so a new
     upstream value is counted, not thrown.
4. Trace every path to the outcome before choosing the emit point. Grep
   the state write (`status = 'paid'`, `insertOrder`, `UPDATE ... SET`),
   not the handler you were pointed at: webhooks, polling or
   reconciliation jobs, admin or manual actions, retries. For each path
   decide: counts, does not count (a manual "mark paid" is not an online
   payment), or counts with a `source` property. Then:
   - Emit on the state transition (from not-X to X), not on the delivery
     of a callback: providers deliver at least once and two paths can
     race (a job reconciles, then the late webhook arrives).
   - Tracking must not break or lose the business write: validate and
     map before mutating, or catch around the emit; never record a
     dedup id or flip the state in a way that makes the provider's retry
     skip an event that was not sent.
   - Carry the time the thing happened (`paid_at` from the provider or
     job) when processing lags it; `sent_at` of a retried webhook or a
     nightly job is not the payment time, and per-day totals shift.
   - Look for a client "success" signal that is not final (a return URL
     `?status=success` for a pending bank payment, an optimistic UI);
     it never emits an outcome.
5. Identity, consent and context, written into the tracking plan:
   - Who is consenting. Users who see a banner are one population;
     visitors on a bare page (payers from a link, logged-out landing
     pages) never see it, so a consent-gated client module drops all of
     their events. Either emit those steps server-side with no personal
     data, or add a prompt there and say the counts cover only those who
     accepted. Never default consent to true or post around the gate.
   - Funnel steps on different footings (one consent-gated client step,
     one ungated server step) give ratios that are wrong, even above
     100%. Put a funnel's steps on one footing or say which are sampled.
   - Context leaks: `page_path`, full URLs, referrers and query strings
     carry tokens, emails and reset codes. Stamp the route template
     (`/pay/:token`) on any page with a credential in the path or query.
   - No PII in properties: names, emails, free text (notes, bank or
     error messages) never; identity travels through `identify`, and
     people who are not users are never identified.
   - Tenant comes from the entity (the invoice's merchant), not from a
     request header the caller (payer, provider webhook) does not send.
   - One view shared by two audiences (a payer page and a merchant
     preview) needs the event on the audience's path, or a property that
     separates them.
   - Moving an existing event to another layer changes its counts (no
     consent loss, no reloads): say so to the data team as a break in
     the series.
6. Audit (both ways, from the code, per platform):
   - Find emissions by transport, not only by call name: the module's
     calls, vendor calls, and anything posting to the collector directly
     (`sendBeacon`, `fetch`/`post` to the collector URL, XHR). A direct
     post bypasses the consent gate and the catalogue; report both.
   - Resolve runtime names (template literals, concatenation, name
     constants or maps) to the concrete names they produce, with the
     properties each carries.
   - Exclude tests, fixtures, stories and commented-out code from the
     emitted set; mention them only as such.
   - Compare values, not only keys: units (major vs minor), pre or post
     discount, the platform value the module stamps against the sheet's
     platform names, an event fired in two places or on every reload.
   - Read the module's delivery path on each platform: consent held only
     in memory, a queue with an unserialised read-modify-write, a flush
     that clears on any response (fetch does not throw on 4xx) or sends
     more than the collector contract accepts. Platform differences in
     counts often live here, not in the event calls.
   - Count: `N in sheet, M distinct names emitted by production code
     (runtime names expanded), K in both`, and list the names on each
     side so the counts can be checked. A sweep that found zero
     emissions in a codebase with an analytics module is a broken
     search, not a clean result.
   - For every mismatch say which side changes (the code, or the sheet
     if the event should exist) or name it as a decision for the user;
     check later decisions under `docs/` before calling the sheet right.
7. Wire (feature or app scope) through the one module per codebase, per
   `references/sdk-wiring.md`; the catalogue matches the sheet by test.
   Write the tests first: the funnel in order on the happy path, the
   duplicate delivery counted once, each other path to the outcome, an
   unexpected upstream value, and that no payload (context included)
   contains the credential or the personal data you excluded.
8. Report under Changed, Verified, Not done, Noticed. Verified lists only
   what ran (the gate, with its count). Not done says what was not
   exercised (a real collector, provider, browser or device, warehouse
   data) and, for an audit, that findings come from reading code, with
   no measured numbers. List every choice you made that the brief left
   open, and the environment keys the engineer must set (names only).

## Output contract

```
## Events: <scope>
sheet: docs/analytics/EVENT_SHEET.md (<N> events)
journeys from: <brief path> | code (derived)
paths to each outcome: <event>: <path> counts | excluded (<why>)
wired: <platform>: <module path>, <T> tests | audit: <N> sheet, <M> code, <K> both, <X> mismatches
not exercised: <collector, provider, browser, device, warehouse>
```

## Gotchas

- An event that fires in two places is two events or one with a
  `source` property; decide, do not let both places guess.
- Screen views are `screen_viewed` with a `screen` property, never one
  event per screen.
- A platform difference in names or properties is a mismatch even when
  both are in the sheet; the sheet has one row per event.
- Vendor and collector keys are configuration, never in the repository.
- A test that the catalogue equals the sheet is only as good as its
  parser: never weaken it to make a new row pass.
