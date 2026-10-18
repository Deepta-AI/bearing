# data-model: design checks

Read when: step 8 and the review: walk each check against the model before writing, and again when the critic grades the schema; the Revising section when the data model already exists.

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
  exclusion constraint can be neither built concurrently nor added `NOT VALID`,
  so changing one is a maintenance window.
- **Uniqueness has a lifecycle.** Case-insensitive uniqueness is
  `lower(col)` or `citext`; scope it (per tenant or global) from the
  story, and say what happens to a closed or soft-deleted row (partial
  index on open rows, or reopen).

## Revising

When `docs/design/data-model.md` (or the data model the
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
