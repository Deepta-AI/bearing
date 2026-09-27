---
name: db-migration
description: 'Writes a database migration with a tested down step and lock-safety notes (goose, Alembic, Prisma, Knex, Room, GRDB, ClickHouse, Mongo). Use when asked to "add a migration", "add a column" or "change the schema".'
argument-hint: "<snake_case_name> [--store postgres|sqlite|clickhouse|mongo]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(ls:*), Bash(mkdir:*), Bash(goose create:*), Bash(goose fix:*), Bash(uv run alembic revision:*), Bash(pnpm exec prisma migrate:*), Bash(make:*)
---

# db-migration

A migration is judged in production, not in the test suite: on the real
row count, with the previous release still serving, with long
transactions in the way, and on the day someone runs its Down in a hurry.
The files and the report answer those four situations; passing the
repository's checks is necessary and nowhere near enough.

## Inputs

- Name: `$1` in snake_case; if absent, derive it from the request and say
  so.
- Tool: `db/migrations/*.sql` with `+goose`, `alembic/`, `prisma/`,
  `knexfile.*`, Room `@Database`, SwiftData schema versions or a GRDB
  migrator. None: the stack's default (Go goose, Python alembic,
  TypeScript prisma); create its layout and config and say so.
- Store: `--store`, else the goose dialect in the Makefile, the driver
  (`sqlite3`, `pgx`, `psycopg`), a `*.db` path or `PRAGMA` calls. Unknown:
  postgres, stated in the report. Never apply the Postgres rules to SQLite.
- Numbering: what is on disk wins over what a README says, and a test that
  checks the sequence wins over the tool's default (goose timestamps fail
  a contiguous-number check; `goose fix` or the next number does not).
- Sizes and limits: read the capacity or operations docs and the ADRs
  before writing a line. Note the row count of every table touched, the
  write rate, the long transactions and when they run, the app's lock
  wait budget (`busy_timeout`, `lock_timeout`, request timeouts), the
  time limit of whatever runs migrations (a pre-deploy job is often
  killed after minutes) and any past migration incident: the incident is
  the rule the reviewer applies.
- Patterns: `${CLAUDE_PLUGIN_ROOT}/skills/database/references/migration-patterns.md`
  for expand and contract and the data test; the header comes from
  `templates/HEADER.sql` in this skill's folder. The header names no
  author and no decider: a name beside a choice reads as an approval
  nobody gave.

## Steps

1. Read the code that touches the tables, not only the schema. Grep every
   query on the table and the new column. Write down, before any SQL:
   which queries read or write the new shape and whether that code is
   already in the tree; what the previous release does against the new
   schema; which rows exist today and what value each must hold.

2. Write the Up, one concern per file, at the next number, header on top.
   - Postgres, any `ALTER` on an existing table: `SET lock_timeout` (the
     ADR's value, else 3s) so the ACCESS EXCLUSIVE request fails fast
     instead of queueing behind a long reader and blocking every write
     queued behind it. Add columns nullable or with a constant default
     (metadata only on PG11+); a volatile default, a type change, or
     `SET NOT NULL` without a validated `CHECK (col IS NOT NULL) NOT VALID`
     rewrites or scans the table under that lock. Foreign keys and checks
     go in `NOT VALID`, then `VALIDATE CONSTRAINT` in a later file.
   - Postgres indexes on tables over about a million rows:
     `CREATE [UNIQUE] INDEX CONCURRENTLY` in a file of its own with
     `-- +goose NO TRANSACTION` (Alembic: `autocommit_block`), Down
     `DROP INDEX CONCURRENTLY`. Uniqueness becomes a unique index built
     this way (then `ADD CONSTRAINT ... USING INDEX` if a constraint is
     wanted), never `ADD CONSTRAINT UNIQUE` under a table lock.
     The build waits for every transaction older than it, so it lasts as
     long as the longest reader: do not copy a short `lock_timeout` into
     this file (it aborts that wait and leaves an INVALID index), and say
     when to run it relative to the long transactions the docs name. If
     the wait plus the build can outlast the job that runs migrations,
     run the index file out of band before the release, not inside that
     job, where a kill leaves the same INVALID index.
     A failed build leaves an INVALID index that every write still pays
     for, and `IF NOT EXISTS` then skips the retry and reports success.
     Make the Up self-healing (`DROP INDEX CONCURRENTLY IF EXISTS` first)
     or omit `IF NOT EXISTS`, and give the check
     (`SELECT indexrelid::regclass FROM pg_index WHERE NOT indisvalid`)
     and the drop-and-retry step. A unique build also fails on existing
     duplicates: say how to find them first.
   - SQLite: one writer, and goose runs each file in one transaction that
     holds the write lock throughout, so compare its duration with
     `busy_timeout`. `ADD COLUMN` is metadata only. `DROP COLUMN` (3.35+)
     and every table rebuild rewrite the whole table, and `DROP COLUMN`
     fails while an index, trigger or view names the column, so a Down
     drops those first. No `ALTER COLUMN`: a type change is a new column
     plus a fill. `PRAGMA foreign_keys` is ignored inside a transaction.
     Multi-statement triggers need goose `StatementBegin`/`StatementEnd`.
   - Index against its query: for each query that reads the new shape,
     check the index serves the predicate as written (leading column
     present, no tenant or soft-delete filter the index lacks). When the
     requested uniqueness is narrower than a lookup (unique per tenant,
     looked up without the tenant), the lookup can return the wrong row:
     state it as a correctness finding with its consequence and the ways
     out, never as an index choice made silently.

3. Existing rows and changing values. A new column is empty for every row
   that exists at deploy time. Ask what the code does with those rows: if
   a lookup by the new column treats "not found" as final (a webhook
   acknowledged, a job skipped), work created before the release is lost
   silently. Find where the value lives today (another table, a JSON
   payload, the external system) and backfill it, or state the gap, its
   size and its consequence. For a conversion:
   - Convert exactly: `CAST(x * 100 AS INTEGER)` truncates (19.99 gives
     1998); round first. NULL stays NULL. Negative values round too.
   - A fill inside a migration file commits once. Batches that commit
     separately need a script or job (goose SQL cannot loop), run after
     the migration at the batch size the operations docs set; compute the
     batch count from the row count and say who runs it and when. The fill
     touches only rows still out of step, so it is idempotent and
     resumable.
   - The release still running keeps writing the old column: inserts that
     set only it, and updates that change it after the fill, leave the new
     column NULL or stale. Cover both (insert and update triggers, or a
     fill that also repairs rows where new differs from converted old) or
     name the gap and when it closes. A trigger fills the new column only
     when the writer left it NULL, so it never overwrites what the next
     release writes itself; say in which release the triggers are dropped.
   - Give the operator a reconciliation query for before the code switch:
     rows where the old value is set and the new one is NULL or differs
     from the conversion, expected 0.

4. Write the Down and judge it as a migration. It reverts everything the
   Up added (triggers and indexes first). If it drops a column, the header
   says in capitals what is lost and what then breaks (a webhook that
   finds nothing, a report that goes blank). State the Down's lock and
   duration: a SQLite `DROP COLUMN` or any rebuild is usually the slow
   direction. A local timing is a lower bound: scale it to the production
   row count and a slower, busier disk, and compare with the lock wait
   budget. When it can exceed that budget, say how to run it (app
   stopped, maintenance window, off-peak), and say that the emergency
   rollback of an additive change is the code rollback alone; the Down is
   a planned step.

5. Order against the code, both ways. If code in the tree or the MR
   already reads or writes the new shape, the migration must be applied
   before that release serves traffic; say so and say what fails if the
   order slips. When the release depends on an index for speed, that
   means the index built and valid, not only the column present. The previous release must keep working on the new schema
   (expand and contract, per the ADRs). Rollback runs the other way: code
   first, then the Down, and only if the Down is needed at all.

6. Prove it with what the repository has. The up, down, up check is
   `make migrate-verify` in the scaffolds, or any test that runs every
   migration up, down and up (look in the test directories first); do not
   add a second one. Read the Makefile before any `make migrate*`: a
   default `DATABASE_URL` or `DB_PATH` that points at staging, production
   or a path outside the repository is never run, even with an override,
   and the report names the risk. Throwaway local databases only. None
   available: say Up, Down and Up were not run against the store and do
   not call the migration verified.
   When rows change (fill, convert, move, delete), write a data test per
   "Testing a data change": migrate to the previous revision, insert
   literal fixture rows as SQL (never through today's code), including
   NULL, empty, a value the naive conversion gets wrong, a negative, a
   soft-deleted row and a duplicate; apply; assert each row's value by id
   and the row count; run the fill twice and after a partial run and
   assert nothing changes; run the Down and assert the only loss is the
   one the header names.

## Output contract

Plain sentences, in this order: the files; what each takes (lock,
duration, on how many rows); the deploy order against the code; the fill
plan with its batch count and the reconciliation query (or "no data
change"); the Down's loss, cost and how to run it; the findings from steps
2 and 3 (lookup and uniqueness mismatches, rows the release leaves empty,
a remote default database); and exactly which checks ran against what,
and what did not run.

## Gotchas

- Room: bump the database version, add `Migration(from, to)` and the
  exported schema JSON; a missing `MigrationTestHelper` test is a finding.
- ClickHouse has no transactional DDL: idempotent statements
  (`IF NOT EXISTS`), the Down as their mirror. Mongo migrations are code:
  a versioned script updating in batches by `_id` range, plus the
  validator change.
- A schema diff proves structure, not content: a Down that recreates a
  dropped column passes up, down, up and still loses every value.
- A freshly created migrations directory has no baseline: the first
  migration is the current schema, the change is the second.
