---
name: analytics-events
description: 'Designs the analytics event sheet, wires the analytics SDK behind one typed module and audits code against the sheet. Use when asked to "track this feature", "add an event", "set up analytics" or "audit tracking".'
argument-hint: "app | feature <name> | event <object_verb> | audit [--platform web|rn|android|ios|backend]"
allowed-tools: Read, Write, Edit, Grep, Glob, Skill, Bash(git diff:*), Bash(make:*), Bash(go test:*), Bash(pnpm test:*), Bash(uv run pytest:*), Bash(./gradlew test:*), Bash(swift test:*)
---

# analytics-events

Events are designed before they are emitted, and the code emits the sheet.
One skill covers every scope so nothing is designed twice or in two shapes.

## Inputs

- scope: `$ARGUMENTS`; if absent, ask one question (app, feature, event
  or audit).
- journeys and stories: `docs/product/backlog.md`; if absent, derived
  from the code: routes (Go mux patterns, FastAPI decorators, React
  Router or expo-router `app/**`), screens (Compose `*Screen`, SwiftUI
  views) and forms, grouped into journeys by navigation; the sheet's
  story column then holds the route or screen name and the report says
  `backlog` gives real ids.
- platforms: detected from `package.json` (`react` or `expo`),
  `build.gradle.kts`, `Package.swift`, `go.mod`, `pyproject.toml`; none:
  design only, and say the wiring waits for code.
- sheet and plan: `docs/analytics/EVENT_SHEET.md` and
  `docs/analytics/tracking-plan.md` in the repository; if absent,
  created from this skill's own `templates/EVENT_SHEET.md` and
  `templates/tracking-plan.md` (a repository `docs/templates/EVENT_SHEET.md`
  is used first when present).
- vendor: an accepted ADR; else the Decisions first protocol below; if
  deferred, the module wires a console destination behind the same
  interface and the report says the vendor is undecided.
- gate: `make check` when the Makefile has a `check` target; if absent,
  the stack's native test command and the report says so.

## Steps

**Decisions first.** Before building, run `tech-decision` for the keys
analytics vendor. `tech-decision` asks only about the keys this task needs that no
accepted ADR, the request or the code already settles, one question at
a time, and records only what the user decides; a key still
awaiting an answer follows
${CLAUDE_PLUGIN_ROOT}/skills/tech-decision/references/decision-protocol.md.

1. Scope as in Inputs:
   - `app`: the whole application. Read the backlog or derive the
     journeys from the code. Produce the event taxonomy for every user
     journey.
   - `feature <name>`: one feature. Read its stories, or its routes and
     screens.
   - `event <object_verb>`: one event, from the user's description.
   - `audit`: no design; compare code and sheet (step 6).
2. Load or create the sheet and the plan as in Inputs (identity, consent,
   platforms, destinations, naming, ownership). Read
   `references/event-design.md` for the rules.
3. Design. For each event: `object_verb` snake_case past tense; when it
   fires (one trigger, one place); properties as `name: type` with
   enumerations spelled out and a source for each value; platforms; the
   story ids (or routes) it serves; owner; the destination (product
   analytics, data warehouse, both). Standard properties come from the
   context layer, never typed by hand per call: `app_version`,
   `platform`, `screen`, `session_id`, `tenant_id`, `experiment`
   variants. No PII in properties; user identity travels through
   `identify`, not through event properties.
4. Identity and consent: define the anonymous id, the user id, when
   `identify` and `alias` fire (login, signup, logout), and how consent
   gates every call (nothing is queued before consent on platforms that
   require it). Write it in the tracking plan.
5. Wire per platform, following `references/sdk-wiring.md`: one
   `analytics` module per codebase with `track(event, props)`, `identify`,
   `screen` or `page`, a typed event catalogue generated from the sheet
   (`src/analytics/events.ts`, `analytics/events.py`, `Analytics/Events.kt`,
   `Analytics/Events.swift`), a context provider that stamps the standard
   properties, a debug mode that logs every event locally, and a test that
   the catalogue matches the sheet (count of events equal, every property
   present). Never call a vendor SDK from a component or handler directly.
6. Audit: grep the code for tracking calls (`track(`, `logEvent(`,
   `capture(`, `analytics.`, `Analytics.logEvent`, `posthog`, `mixpanel`,
   `segment`, `amplitude`) and extract event names and property keys.
   Compare both ways. Print `N events in sheet, M in code, K mismatches`
   (emitted but not designed, designed but never emitted, property drift,
   the same event with different shapes on two platforms). Zero events on
   both sides is a result to report, not an error.
7. Report in the four headings (Changed, Verified, Not done, Noticed);
   under Not done list the vendor keys the engineer must add to the
   environment (names only).

## Output contract

```
## Events: <scope>
sheet: docs/analytics/EVENT_SHEET.md (<N> events, <P> properties)
plan:  docs/analytics/tracking-plan.md (identity, consent, <D> destinations)
journeys from: backlog | code (<N> routes and screens)
wired: <platform>: <module path>, catalogue <path>, <T> tests
audit: <N> in sheet, <M> in code, <K> mismatches
```

## Gotchas

- An event that fires in two places is two events or one event with a
  `source` property; decide, do not let both places guess.
- Screen views are `screen_viewed` with a `screen` property, never one
  event per screen.
- Property values that come from user text are PII; hash or drop them.
- A platform difference in names or properties is a mismatch even when
  both are in the sheet; the sheet has one row per event, not per platform.
- Vendor SDK keys are configuration, never in the repository.
- Journeys derived from routes describe what the app can do, not what
  users are meant to do; mark them "derived" in the sheet until the
  backlog confirms them.
