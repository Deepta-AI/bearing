---
name: low-level-design
description: 'Writes a Low Level Design (LLD) refining one HLD component into modules, types, error paths, indexed queries, tests and MR-sized work. Use when asked for an "LLD", "low level design" or "detailed design".'
argument-hint: "<component> [--hld docs/design/<title>-hld.md]"
allowed-tools: Read, Write, Grep, Glob, Skill, Agent
---

# low-level-design

An LLD turns one component of an approved HLD into files, types, queries
and MRs. It never re-opens the goal, the store or the boundaries; those
are settled in the HLD and its ADRs. Every sequence carries its error
branches, every query names its index, and every work item is small
enough to review in one sitting.

Not this: `high-level-design` sets the goal, the boundaries and the stores; this
refines one component of an agreed HLD and never reopens them.

## Inputs

- Component: looks in `$ARGUMENTS`; if absent, asks one question.
- HLD: looks in `--hld`, else the single `docs/design/*-hld.md` naming
  the component; if absent, the boundary is read from the code (the
  package, its routes, tables and queues) and `docs/adr/`, confirmed with
  one question, and the Refines line reads `none (boundary from code)`;
  `high-level-design` produces the fuller HLD.
- Layout rules: the stack skill for the language (`bearing-backend:go`,
  `bearing-apps:react`, `bearing-backend:python`, `bearing-apps:react-native`,
  `bearing-apps:android`, `bearing-apps:ios`) when installed; if absent, the repository's existing layout as `ls` shows it.
- Data rules: looks in `docs/design/data-model.md`; if absent, the
  migrations and models in the code.
- API shapes: looks in `api/openapi.yaml`; if absent, request and
  response types are written inline; `openapi-spec` produces the contract.
- Config: looks in `.env.example`; if absent, every variable is listed as
  missing from it.
- Ids: from the HLD and `docs/product/backlog.md`; if absent, `Serves:
  unnumbered`.
- Template: looks in `docs/templates/LLD.md`; if absent, this skill's
  `templates/LLD.md`.
- Delivering entity: looks in `.bearing/company.json`; if absent, the title
  page reads "unattributed" and the run continues.
- Task id: `.git/HEAD` names the branch; a task id in it goes on the
  title page, else `Task: none`.
- This skill runs in the main conversation, not forked: it asks the
  user to confirm a code-derived boundary and forks `critic`, which
  a forked document writer cannot. It has no shell; existing files come
  from Glob, line counts from Read.

## Steps

**Revising.** When the output file already exists, this run is a
revision: read `${CLAUDE_PLUGIN_ROOT}/skills/adr/references/revision-protocol.md`
and follow it (version line, changes table, superseding ADR,
critic on changed sections, downstream list). A revision that moves the component's boundary is an HLD change first: say so and stop, naming high-level-design.

1. Component from `$ARGUMENTS`; HLD and the other sources under Inputs,
   each printed as read or absent. Read the template (repository copy
   when present, else `templates/LLD.md`), the HLD or the code-derived
   boundary, the ADRs, and the layout rules
   (${CLAUDE_PLUGIN_ROOT}/skills/<lane>/SKILL.md, Layout section).
   Carry the HLD's ids to the
   top of the document and add the `AC-US-nn-nnn-k` ids the tests will
   cover.
2. Scope: the one component and its boundary, in two sentences. Refuse a
   scope that spans two components; write two LLDs.
3. Module layout: packages and files, what each owns, mirroring the stack
   skill's layout. Existing files come from Glob; new ones are marked
   `(new)`. A file expected to pass 400 lines is split here, not later.
4. Types and schemas: domain types, boundary schemas (request, response,
   event, config) and the one place each is validated. Point at
   `api/openapi.yaml` for HTTP shapes rather than repeating them.
5. Sequence: one mermaid `sequenceDiagram` per flow, with `alt` blocks
   for every error branch. A flow with no error branch gets the line
   `UNDEFINED error branch` so it is visible.
6. Data access: each query with the index it uses and the query shape,
   transaction boundaries (what is inside, what is not, and why), and the
   migrations in order as `db-migration` names. For every job, queue or
   scheduled work: how many workers can run it at once (the HLD, the
   deployment's replica count, or the worker config) and how two of them
   are kept from taking the same item (a claim with `FOR UPDATE SKIP
   LOCKED`, a lease with an expiry, a unique key); "a single worker" is a
   design only when the deployment pins it to one and the document says
   what happens when a second one starts anyway. Rules come from
   `docs/design/data-model.md` when it exists.
7. Errors: each error type, where it is created, where it is wrapped,
   where it is mapped to a status code or user message. HTTP errors use
   the repo's JSON envelope (`openapi-spec`).
8. Configuration: every variable, its default, and what happens when it
   is missing. Each must appear in `.env.example`; list any that do not.
9. Tests by name: unit, integration, end-to-end, each tagged with the
   `AC-US-nn-nnn-k` or `TC-nnnn` it proves. Every retry, fallback or
   limit rule gets two: one where the retry succeeds (a 429 then a 200)
   and one where it gives up at the limit.
10. Work breakdown: ordered items, each naming the files it touches, the
    tests it adds and an estimated line count. Any item over 400 lines is
    split before the document is written. Zero items means the design is
    not done. Before writing, check the order: for every type, function
    and table an item uses, the item that defines it is the same item or
    an earlier one; move or merge items until that holds.
11. Write `docs/design/<kebab-component>-lld.md` and print the output
    contract.
12. Critic: ask the user whether to run it. On yes, fork `critic`
    (Agent tool) with the document path, append its weakest claims and
    verdict under "Assumptions", and put its verdict line in the
    contract.

## Output contract

```
## LLD: <component>
Path: docs/design/<kebab-component>-lld.md
Refines: docs/design/<title>-hld.md
Serves: US-..., AC-US-..., TC-..., ADR-...
Files: N (new: K)   Sequences: N (UNDEFINED error branches: K)
Queries: N (without index: K)   Transactions: N
Config vars: N (missing from .env.example: K)
Tests named: N
Work items: N (largest est. lines: L; over 400: 0)
Assumptions: K
Questions returned: K (boundary confirmation | none)
Critic: run (<verdict line>) | declined
Revision: v<n> -> v<n+1>, sections changed C, ADRs superseded S, downstream D | v1 (new)
```

## Gotchas

- The author line and any delivering entity on the title page come from
  `.bearing/company.json` (`company-attribution`); when it is absent write
  "unattributed", never a guessed company.

- An LLD that changes a boundary set in the HLD is a new ADR plus an HLD
  edit, not a quiet paragraph here.
- "Add index later" is a query without an index. Name it or mark the
  query as a known full scan with the row count.
- Work items are ordered so every MR leaves `make check` green. An item
  that only compiles once the next one lands is two items in the wrong
  order.
- No em dashes; short sentences; diagrams in mermaid so they diff.
