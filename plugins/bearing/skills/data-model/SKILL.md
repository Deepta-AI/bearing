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
`${CLAUDE_PLUGIN_ROOT}/skills/adr/references/revision-protocol.md`; edit
in place, applied migrations are history. Detail: references/revising-and-decisions.md

**Decisions first.** Before building, run `tech-decision` for the keys
database and analytics store, and only for the stores this scope needs.
The data access library is not a data model decision: do not raise it,
record it or write an ADR for it here. Detail: references/revising-and-decisions.md

1. Read the sources under Inputs, each printed as read or absent: the
   stories, the HLD data section, ADRs that choose a store, existing
   migrations and models. Zero stories and zero entities: ask the one
   question under Inputs. Detail: references/sources-entities-relationships.md
2. Entities: one row each with owner, lifecycle (every writer path), the
   `US-nn-nnn` ids it serves, PII yes or no, retention. An unused entity is cut.
3. Relationships: one row per foreign key with cardinality, FK column,
   `ON DELETE` and why; the `erDiagram` goes to `erd.md`. Detail: references/sources-entities-relationships.md
4. Why these stores: per store, what it holds and why, with a Considered
   | Why not table naming the requirement each rejected store fails.
5. Per store, following the reference for that store: Postgres tables
   with a column table whose Why quotes the acceptance criterion (a
   column with no Why is cut), MongoDB collections, ClickHouse tables.
   Detail: references/stores-retention-migrations.md
6. Enumerations: one row per enum with its values and why the set is
   closed. Retention: one row per table with a lifetime and its mechanism;
   a lifetime no story states is `UNDEFINED`, never a suggested number.
   Detail: references/stores-retention-migrations.md
7. Migration plan in order, each item named and numbered the way the
   repository's existing migrations are, with its lock risk on a hot
   table. The plan writes no migration file. Detail: references/stores-retention-migrations.md
8. Rule check: walk the applicable rules of each reference. Every rule is
   followed or has a line `deviation: <rule>, <why>`. Count both.
9. Write the four files (a new model; for a revision see Revising), from
   this skill's templates, into `docs/design/`. Detail: references/write-and-review.md
10. Review: fork `critic` with the paths of `data-model.md` and
    `schema.sql` and the stories file, asking it to argue against the
    schema from the acceptance criteria and the Design checks below, and
    grade each finding. Fix what can be fixed in this run. Detail:
    references/write-and-review.md
11. Gate: `python3 "${CLAUDE_PLUGIN_ROOT}/skills/data-model/scripts/model_check.py" --dir docs/design`.
    It fails on zero tables, on a mismatch between the SQL and the
    dictionary and on more cases. Detail: references/write-and-review.md.
    Fix and rerun until it prints 0
    problems. Then prove it applies:
    `bash "${CLAUDE_PLUGIN_ROOT}/skills/data-model/scripts/apply_check.sh" docs/design/schema.sql`
    (a throwaway `postgres:16` container, no port, no shared database;
    SKIPPED without Docker). Paste both lines under "Applying this" and
    print the output contract.

## Design checks

Walk each check against the model before writing; each that applies is a
row, a constraint or an open concern, never silence. Detail: references/design-checks.md

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
