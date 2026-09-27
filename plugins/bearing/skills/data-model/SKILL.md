---
name: data-model
description: 'Designs the data model from the stories: data-model doc, runnable schema.sql, data dictionary and ERD, a reason per column. Use when asked to "design the data model", "what tables do we need" or "draw the ER diagram".'
argument-hint: "[feature or system] [--stores postgres,mongodb,clickhouse]"
allowed-tools: Read, Write, Edit, Grep, Glob, Skill, Agent, Bash(ls:*), Bash(mkdir:*), Bash(python3 *skills/data-model/scripts/model_check.py*), Bash(bash *skills/data-model/scripts/apply_check.sh*)
---

# data-model

The data model is where stories become columns. It names who owns each
entity, how it is born and dies, which store holds it and why, and the
reason behind every column, index and constraint: the acceptance criterion
or rule it exists for. It obeys the rules in `database`; a deviation is
written down with its reason, never slipped in. Four files leave this
skill and a gate proves they agree: the document, a runnable `schema.sql`,
a data dictionary and an ERD.

## Inputs

- Stories: looks in `docs/product/backlog.md` and `docs/product/PRD.md`;
  if absent, entities come from the migrations, models, ORM schema and
  route payloads in the code; if the code has none, asks one question for
  the entity names or a brief, and the Serves line reads `unnumbered`;
  `backlog` produces the fuller backlog. Nothing after that stops the
  skill: "provide stories, a schema or the entity names".
- Stores: looks in `--stores`, else the ADRs; if absent, Postgres, and
  the output reads `ADR needed`.
- HLD data section: looks in `docs/design/*-hld.md`; if absent, entity
  ownership comes from the module layout.
- Store references: `database` under the plugin root; always present.
- Templates: `templates/data-model.md`, `templates/schema.sql`,
  `templates/data-dictionary.csv` and `templates/erd.md` in this skill; one
  worked example (customers, invoices) that already passes the gate.
- Gate: `scripts/model_check.py` (Python 3 standard library) and
  `scripts/apply_check.sh` in this skill; without Docker the apply proof
  prints SKIPPED and the stdlib gate still runs.
- Critic: the `critic` agent; if the Agent tool is unavailable, the
  review section reads "review: not run (no agent)" and the output
  contract says so.

## Steps

**Revising.** When `docs/design/data-model.md` (or the data model the
repository already has) exists, this run is a revision: read
`${CLAUDE_PLUGIN_ROOT}/skills/adr/references/revision-protocol.md` and
follow it. The existing document is approved work a reviewer will diff:
edit it in place, keep its layout, headings, numbering and wording, and
change only the rows the new stories touch. Do not move it onto this
skill's template, and create companion files (`schema.sql`, dictionary,
ERD) only if the repository already has them; the gate then runs on what
exists or reads "n/a (revision of a document without companions)".
Applied migrations are history: every change is a new migration after the
highest number, planned against the live table's size and locks. In a
revision the Migrations line counts only the migrations the changed rows
require, each named for `db-migration` with its expand and contract steps.

**Decisions first.** Before building, run `tech-decision` for the keys
database and analytics store, and only for the stores this scope needs.
The data access library (ORM, query builder, sqlc) is not a data model
decision: do not raise it, record it or write an ADR for it here.
`tech-decision` asks only about the keys this task needs that no
accepted ADR, the request or the code already settles, one question at
a time, and records only what the user decides; a key still
awaiting an answer follows
${CLAUDE_PLUGIN_ROOT}/skills/tech-decision/references/decision-protocol.md.

1. Read the sources under Inputs, each printed as read or absent: the
   stories, the HLD data section, ADRs that choose a store
   (`grep -il 'postgres\|mongo\|clickhouse' docs/adr/`), existing
   migrations and models. Stores from `--stores` or the ADRs; none named
   means Postgres (the default in `database`). Read the matching
   references from the plugin root:
   `${CLAUDE_PLUGIN_ROOT}/skills/database/references/postgres.md`,
   `mongodb.md`, `clickhouse.md`, and `migration-patterns.md`. Zero
   stories and zero entities in the code: ask the one question under
   Inputs and model from the answer.
2. Entities: one row each with owner (service or module), lifecycle
   (created by, changed by, ended by: delete, archive, expiry; every
   writer path), the
   `US-nn-nnn` ids it serves, PII yes or no, retention. An entity no
   story reads or writes is cut and listed under "not modelled".
3. Relationships: one row per foreign key with its cardinality, FK
   column, `ON DELETE` and why; the mermaid `erDiagram` (every entity,
   every relationship with its cardinality, the FK columns named) goes to
   `erd.md` with one sentence per relationship.
4. Why these stores: per store, what it holds and why, with a Considered
   | Why not table naming the requirement each rejected store fails.
5. Per store, following the reference for that store:
   - Postgres: per table, in foreign-key order, the purpose, `Serves
     US-...`, expected volume with its order of magnitude (10^n) and what
     drives it, hot or not. A column table (Column, Type, Null, Key,
     Default, Description, Why): Why quotes the acceptance criterion or
     names the rule the column exists for; a column with no Why is cut.
     Ids, `timestamptz` audit columns, `NOT NULL` by default, FK with
     explicit `ON DELETE` and an index on the referencing column,
     `tenant_id` first in composite keys. Each index named
     `idx_<table>_<cols>` (unique: `uq_`) with the query it serves and the
     predicate it must repeat; partial, covering and BRIN where the
     reference says. Each CHECK named `chk_<table>_<rule>` with the bad row
     it refuses.
   - MongoDB: each collection with a `$jsonSchema` validator sketch
     (`required`, `bsonType`, `maxItems`, `maxLength`,
     `additionalProperties: false`, `schemaVersion`), the embed or
     reference decision with its bound, and an index per query shape.
   - ClickHouse: engine and why, `ORDER BY` with the rationale (equality
     filters first, lowest cardinality first, three to five columns),
     partition key, TTL, the version column for `ReplacingMergeTree`,
     and the materialised views with their `TO` targets.
6. Enumerations: one row per enum with its values and why the set is
   closed. Retention: one row per table with a lifetime, its rule and the
   mechanism that enforces it (batched hard delete, TTL, partition drop).
   A lifetime no story, PRD or policy states is `UNDEFINED`, with an owner
   question; a number you would suggest goes in that question, never in
   the lifetime cell and never into a purge job, TTL or partition scheme.
   Then the personal-data columns, each with its kind.
7. Migration plan in order, each item named and numbered the way the
   repository's existing migrations are (next free number, same tool and
   file style; claim no convention the repository does not have), with
   its lock risk on a hot table, the batch note, and the expand, migrate
   or contract phase it belongs to; `db-migration` writes them later.
   The plan writes no migration file. A new database is migration 1:
   `schema.sql`.
8. Rule check: walk the applicable rules of each reference. Every rule is
   followed or has a line `deviation: <rule>, <why>`. Count both.
9. Write the four files (a new model; for a revision see Revising), from
   this skill's templates, replacing the worked example: `docs/design/data-model.md` (headline line: store,
   tables, columns, indexes, personal-data columns);
   `docs/design/schema.sql` (one `BEGIN;` ... `COMMIT;`, enum types first,
   tables in foreign-key order, a `-- Serves US-...` comment before each
   table, `COMMENT ON TABLE` and `COMMENT ON COLUMN` for every table and
   column, then its indexes); `docs/design/data-dictionary.csv` (one row
   per Postgres column, header `Table,Column,Type,Nullable,Key,Default,References,On Delete,Personal Data,Description,Why`);
   `docs/design/erd.md` (mermaid `erDiagram` and one sentence per
   relationship). With no Postgres store, `schema.sql`, the dictionary and
   the gate are "n/a (no postgres store)".
10. Review: fork `critic` with the paths of `data-model.md` and
    `schema.sql` and the stories file, asking it to argue against the
    schema from the acceptance criteria and the Design checks below, and
    grade each finding BLOCKER
    (the schema cannot serve a criterion, or does not apply), MAJOR (a
    criterion is served wrongly or a guarantee is missing), MINOR or NIT,
    each with the table, the failure and the fix. Fix what can be fixed in
    this run and mark it fixed; write the rest under "What the review
    found" with Status open. Then write "Open concerns": each tagged
    `[conflict]`, `[gap]`, `[ambiguity]`, `[risk]` or `[scope]`, with an
    owner, a date and "Blocks development: yes | no".
11. Gate: `python3 "${CLAUDE_PLUGIN_ROOT}/skills/data-model/scripts/model_check.py" --dir docs/design`.
    It fails on zero tables, on any table or column in the SQL but not in
    the dictionary or the reverse, on an empty Why, on a table or column
    with no `COMMENT ON`, on an unnamed CHECK, on FK order, and on
    headline counts that disagree. Fix and rerun until it prints 0
    problems. Then prove it applies:
    `bash "${CLAUDE_PLUGIN_ROOT}/skills/data-model/scripts/apply_check.sh" docs/design/schema.sql`
    (a throwaway `postgres:16` container, no port, no shared database;
    SKIPPED without Docker). Paste both lines under "Applying this" and
    print the output contract.

## Design checks

A strong generalist gets the tables right and misses these. Walk each one
against the model before writing; each that applies is a row, a
constraint or an open concern, never silence.

- **Every writer, every column.** List each path that writes a table
  (front desk, online, reschedule, admin, jobs). For every `NOT NULL`
  column, name where each path gets the value; a new path with no source
  (a fee a receptionist used to type) is a gap in the model, not in the
  code. A rule enforced by application cleanup must hold on every path,
  or move into the database (constraint, trigger, one shared function).
- **Tenant-safe references.** A single-column FK lets a row point at
  another tenant's parent. Add `UNIQUE (tenant_id, id)` to the parent (a
  new migration on an existing table) and reference `(tenant_id, x_id)`,
  or say why not.
- **Requirements the existing tables do not carry.** A story that needs a
  column on an existing table (a default per doctor, a currency per
  clinic) adds it by a new migration; never by editing an applied one.
  Check each ADR's wording against the real scope: an ADR written for one
  country ("paise") does not settle currency for clinics in three.
- **Predicates are immutable.** Index, constraint and generated-column
  expressions cannot call `now()`. Anything that expires (a hold, a code,
  a lease) needs a sweeper, a check inside the writing transaction, or a
  trigger; state which, and the longest time an expired row can still
  block.
- **Derived rows follow their parent.** For each row created from another
  (a reminder from an appointment), say what cancel, reschedule and
  delete do to it, and reset the exact column the worker's index reads.
- **Lifetimes compose.** A parent purged at N years must take its
  children (`ON DELETE CASCADE` or deleted first in the same batch), and a
  child with its own longer rule blocks the parent. A person's erasure
  request against a table another table must keep (clinical, financial)
  means `RESTRICT` plus erasing the non-required fields, never `CASCADE`
  into records the law says to keep.
- **Size from the rule, then decide.** Steady-state rows = yearly rate x
  retention (plus growth). Use the number: batched delete below about
  10^7 rows, time partitions or BRIN above, and say what partitioning
  costs (PostgreSQL 16 cannot put an exclusion constraint on a
  partitioned table).
- **Time is local where people are.** A "day" is bounded in the tenant's
  zone (`tenants.timezone`), converted at query time; store `timestamptz`.
- **Ambiguous numbers are read aloud.** "Retried up to 3 times" is 3 or 4
  attempts; state the reading, make the limit match it and ask.
- **Hot-table changes.** On a table over about 10^6 rows: `NOT VALID` then
  `VALIDATE` for CHECK and FK, `CREATE INDEX CONCURRENTLY` outside a
  transaction (goose: `-- +goose NO TRANSACTION`), and note that an
  exclusion constraint can be neither built concurrently nor added `NOT
  VALID`, so changing one is a maintenance window.
- **Uniqueness has a lifecycle.** Case-insensitive uniqueness is
  `lower(col)` or `citext`; scope it (per tenant or global) from the
  story, and say what happens to a closed or soft-deleted row (partial
  index on open rows, or reopen).

## Output contract

```
## Data model: <scope>
Path: docs/design/data-model.md
Files: schema.sql, data-dictionary.csv, erd.md (docs/design/) | n/a (no postgres store)
Serves: US-..., REQ-..., ADR-...
Stores: postgres, ... (ADR: ADR-nnnn | ADR needed)
Entities: N (not modelled: K)
Tables: N   Collections: N   CH tables: N
Indexes: N (query shapes without index: K)
PII columns: N (UNDEFINED retention: K)
Migrations: N (hot-table batches: K)
Rules checked: N   Deviations: K
- deviation: ...
Review: BLOCKER b, MAJOR m, MINOR n, NIT t (open O) | not run (<reason>)
Open concerns: N (blocks development: K)
Gate: data-model: <model_check.py counts line, verbatim>
Apply: schema-apply: <apply_check.sh line, verbatim> | SKIPPED (<reason>)
Revision: v<n> -> v<n+1>, sections changed C, ADRs superseded S, downstream D | v1 (new)
```

## Gotchas

- A query shape the stories imply but no index serves is a finding, not
  a footnote. List it under the count.
- Never pick a second store here. ClickHouse or Mongo alongside Postgres
  is an ADR; write "ADR needed" and model it as if the ADR passes.
- Do not copy the reference's rules into the document. Point at them
  and record only the deviations.
- Soft delete without the partial unique index and the batched hard
  delete is half a rule. Follow all of it or deviate in writing.
- DDL lives in `schema.sql` only. The document gives the reason for each
  piece and never repeats the DDL, so the two cannot drift; the gate
  checks the names and counts that tie them.
- A Why that says "needed" or "standard" is empty. It quotes the
  criterion, names the rule, or the column goes.
- The data dictionary and `schema.sql` cover Postgres. Mongo collections
  and ClickHouse tables are documented in their sections of the document
  and in their own ERD diagram.
- An open BLOCKER from the review means the model is not ready; say so in
  the output contract instead of calling the run done.
- An unstated retention is a decision owed by a person, not a default.
  Count it as UNDEFINED; never promote a suggestion to the rule.
- The files this skill writes are the four under `docs/design/`. An
  ADR, a glossary, a sibling LLD or a migration file is outside the
  request: name what else goes stale under the downstream list instead
  of editing it.
- The Author line is the person who ran the skill (`git config
  user.name`) or "draft, unreviewed"; never a name guessed from the
  repository or the prompt.
- No em dashes, including inside `COMMENT ON` strings and CSV cells.
