# data-model: revising, and decisions first

Read when: the run is a revision (the repository already has a data model), and before building when a store key is open.

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
