---
name: feature-patterns
description: 'Plans one common feature mechanism before code: uploads, search, realtime, caching, rate limits, payments, notifications, multitenancy. Use when asked to "add file uploads", "add realtime" or "rate limiting".'
argument-hint: "[uploads|search|realtime|cache|rate_limit|payments|notifications|multitenancy]"
allowed-tools: Read, Write, Grep, Glob, Bash(ls:*), Bash(mkdir -p:*), Bash(date:*)
---

# feature-patterns

Eight problems every product meets, each solved badly the first time.
One reference per pattern holds the decision, the tables, the ways it
fails and the tests that catch them. The skill loads one, asks the
pattern's questions, and writes a plan the implementation follows.

Not this: `tech-decision` for a technology choice with an ADR; `high-level-design`
for the whole system. This skill plans one mechanism inside a design.

## Inputs

- pattern: `$1`, one of the eight names; if absent or unknown, the list
  below is printed and the skill stops.
- stack: `go.mod`, `pyproject.toml`, `package.json` (react or expo),
  `build.gradle.kts`, `Package.swift`; none or several: the plan keeps
  the pointers for every stack and says so.
- existing implementation: `Grep` for the reference's "Markers" line;
  hits listed so the plan extends rather than duplicates.
- ADRs: `docs/adr/*.md` grepped for the reference's decision keys; an
  accepted ADR answers a question without asking it.
- load numbers: `docs/architecture/HLD.md` or `docs/design/*-hld.md`
  section "Scaling and limits"; if absent, the questions ask for them.
- references in this skill: `references/uploads.md`, `references/search.md`,
  `references/realtime.md`, `references/cache.md`, `references/rate_limit.md`,
  `references/payments.md`, `references/notifications.md`,
  `references/multitenancy.md`.
- output: `docs/design/<name>-pattern.md`; when it exists, the plan is
  revised in place (a `Changes` line naming what moved), not duplicated.

## Patterns

| Name | One line | Reach for it when |
| --- | --- | --- |
| uploads | presigned uploads, scanning, limits, image processing | users send files |
| search | Postgres full text against OpenSearch or Typesense, indexing, relevance tests | a list needs a search box that works |
| realtime | SSE, WebSocket or polling, fan-out, reconnect, ordering | the screen must change without a refresh |
| cache | cache-aside, TTL and invalidation, stampede protection, keys | one read is too slow or too frequent |
| rate_limit | token bucket or sliding window, per key and tenant, headers | one caller can hurt the others |
| payments | idempotent charge, provider webhooks, ledger, refunds, PCI scope | money moves |
| notifications | channels, templates, preferences, batching, unsubscribe, log | the product must reach people |
| multitenancy | row, schema or database per tenant, id propagation, limits | more than one customer shares the system |

## Steps

1. Without a name: print the table above with "8 patterns; run
   `feature-patterns <name>`" and stop.
2. With a name: read exactly `references/<name>.md`. Nothing else from
   `references/` is loaded.
3. Grep the repository for the reference's Markers line. Print "N
   existing hits" with paths; zero is a valid result and is said.
4. Read the load numbers and the ADRs. Ask the reference's decision
   questions one at a time, each with its recommendation and reason;
   skip any question an accepted ADR answers and cite it. Record every
   answer.
5. Write `docs/design/<name>-pattern.md`: decisions (choice and reason per
   question), data model (the reference's tables adapted to the
   answers), endpoints, jobs and flow, failure modes with the handling
   chosen for each, tests to write (one line each, named so
   `test-cases` can take them), per-stack pointers for the detected
   stack only, `adr "<title>"` for each decision without an ADR, and
   open questions.
6. Print the contract. No production code is written here; the plan
   feeds `test-driven-development` and `db-migration`.

## Output contract

```
## Pattern: <name> (references/<name>.md)
Stack: <stack | all>   Existing: N hits (<paths | none>)
Decisions: D asked, A from ADRs, U open
| Question | Choice | Reason |
...
Data model: <tables>   Failure modes: F handled   Tests to write: T
ADRs to record: adr "<title>" ...
Plan: docs/design/<name>-pattern.md
```

Without a name: `## Patterns: 8` followed by the table.

## Gotchas

- One reference at a time. Loading all eight fills the context and
  decides nothing.
- A pattern chosen without its load number is a guess; the questions
  ask for the number and the plan writes it down.
- The plan lives in `docs/design/` so a reviewer finds it on the branch
  beside the code it drives; a plan in `.scratch/` is invisible to them.
  The decisions still go to ADRs, the schema to a migration and the
  tests to the suite.
- Existing hits are read before any question. A second cache layer or a
  second webhook handler is the usual way these patterns go wrong.
- payments and multitenancy touch money and isolation; `threat-model`
  runs before the code, not after.
- Per-stack pointers name libraries as options. A new dependency still
  goes through the team's rules and `dependency-audit`.
