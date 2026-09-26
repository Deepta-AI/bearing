---
name: db-migration
description: 'Writes a database migration with a tested down step and lock-safety notes (goose, Alembic, Prisma, Knex, Room, GRDB, ClickHouse, Mongo). Use when asked to "add a migration", "add a column" or "change the schema".'
argument-hint: "<snake_case_name> [--store postgres|sqlite|clickhouse|mongo]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(ls:*), Bash(mkdir:*), Bash(goose create:*), Bash(uv run alembic revision:*), Bash(pnpm exec prisma migrate:*), Bash(make:*)
---

# db-migration

Every migration answers three questions in its header: what it changes,
what index decision it makes, and what lock it takes for how long.

## Inputs

- Name: `$1` in snake_case; if absent, one question: "what does the
  migration change, in three words?". Nothing: stop with "provide a name".
- Tool: detected from `db/migrations/*.sql` with `+goose`, `alembic/`,
  `prisma/`, `knexfile.*`, Room `@Database` classes, `SwiftData` schema
  versions or a GRDB migrator; if none, one question: "which tool: goose,
  alembic, prisma, knex, room, swiftdata, grdb, clickhouse or mongo?" (the
  stack suggests the default: Go goose, Python alembic, TypeScript prisma).
  The directory is then created with the tool's layout: `db/migrations/`
  (goose, knex, clickhouse), `alembic/versions/` plus `alembic.ini` and
  `env.py` (alembic), `prisma/migrations/` (prisma), a `migrations/`
  package beside the `@Database` class (room), a `Migrations/` group
  (swiftdata, grdb), `db/migrations/*.js` (mongo).
- Store: `--store`; if absent, the goose dialect in the Makefile, the
  driver (`sqlite3`, `pgx`, `psycopg`), a `*.db` path or `PRAGMA` calls,
  the schema files; if still unknown, postgres, said so in the report.
  Never apply the Postgres rules to a SQLite store: they differ (step 4).
- Patterns: looks in
  `${CLAUDE_PLUGIN_ROOT}/skills/database/references/migration-patterns.md`;
  if the plugin root is unknown, the header comes from `templates/HEADER.sql`
  in this skill's folder and the rules in step 4.
- Task id: the branch name; if absent, a `<TASK>` placeholder. The header
  names no author and no decider: the file records what the migration
  does, and a person's name beside a choice (a rejected index, a phase
  plan) reads as their approval, which nobody gave.

## Steps

1. Resolve the name, tool and store as in Inputs. Create the directory and
   the tool's config when they do not exist and say so.
2. Read the patterns reference for the expand and contract recipe and the
   header block, or use `templates/HEADER.sql`.
3. Create the file with the tool's own command when it has one (`goose
   create <name> sql`, `uv run alembic revision -m <name>`), otherwise the
   next number in sequence. One concern per migration.
4. Fill Up and Down. The header block goes at the top: purpose, row
   count the plan assumes (from the capacity or operations docs, or "not
   known"), index decision, the lock each direction takes and for how
   long, rollback note. The Down is a migration too: state its lock and
   duration as well as the Up's, measured on a prod-sized copy when one
   can be generated locally, otherwise "not measured".
   - Index against its query: grep the code for every query that reads
     the new column and check the index serves it as written (leading
     column in the predicate, no missing tenant or soft-delete filter).
     A uniqueness rule that is narrower than the lookup (unique per
     tenant, looked up without the tenant) is a correctness finding for
     the report, not only an index choice. With a local database,
     `EXPLAIN` the query after the Up and quote the plan line.
   - Postgres: add columns nullable or with a default, backfill in a
     separate batched job, `CREATE INDEX CONCURRENTLY` with
     `-- +goose NO TRANSACTION` (or `op.execute` outside a transaction in
     Alembic) on tables over a million rows, no in-place type change on a
     hot table. A failed concurrent build leaves an INVALID index that
     still slows writes, and `IF NOT EXISTS` then skips the retry and
     reports success; the header or report says to check
     `pg_index.indisvalid` and `DROP INDEX CONCURRENTLY` it before
     retrying. Omit `IF NOT EXISTS` on a concurrent build for that reason.
   - SQLite: one writer, and the whole migration holds the write lock, so
     compare its duration with the app's `busy_timeout`. `ADD COLUMN` is
     metadata only; `DROP COLUMN` (3.35+) and every table rebuild rewrite
     the table under that lock, which usually makes the Down the slow
     direction. `ALTER COLUMN` does not exist; a type change is a new
     column plus a batched fill. Fill in batches small enough to commit
     inside the busy_timeout, with the batch size the operations docs set.
   - Never write a Down that loses data silently; if the Down drops a
     column, the header says so in capitals.
5. Prove the Down with what the repository already has: `make
   migrate-verify` in the go-api, python-api and node-api scaffolds, or
   any existing test that runs every migration up, down and up again
   (look in the test directories before deciding there is none). Run it
   against a local or throwaway database only. Drizzle needs
   `drizzle/down/<name>.sql` beside each migration; write it. Only when
   the repository has no such check at all, propose the go-api Makefile's
   `migrate-verify` in the report rather than adding tooling to a
   migration change; if the user asked for it, add it in its own commit,
   reading a separate `VERIFY_DATABASE_URL` that defaults to localhost,
   never the `DATABASE_URL` the other targets use. No database available:
   say the Up, Down and Up were not run, and do not call the migration
   verified.
6. Prove the data, when the migration or its backfill changes rows that
   already exist (moves, splits, merges, converts, fills or deletes
   them); a migration that only adds structure skips this and says so.
   Write a data test beside the repository's integration tests, following
   "Testing a data change" in the patterns reference:
   - Migrate to the revision before this one, insert literal fixture rows
     through SQL (never through today's code, which already expects the
     new shape): an ordinary row, NULL and empty values, the longest
     value, non-ASCII text, a duplicate the new constraint must handle, a
     soft-deleted row.
   - Run the Up (or the backfill job). Assert, row by row, the value each
     fixture row must now hold, and that the row count is what the header
     says it is.
   - Run the backfill a second time and assert nothing changed (it is
     idempotent), and stop it after one batch and run it again to assert
     it resumes without doubling work.
   - Run the Down and assert the only loss is the one the header's "Down
     loses" names.
   Name the test file in the header's `tested in:`.
7. Report: file path, the header, the command that proves the Down, and
   the data test or "no data change".

## Output contract

```
## Migration: <file>
Tool: <tool> (<detected | chosen>)   Store: <store>   Directory: present | created
Header: <purpose> / rows <count> / index <decision, query it serves> / lock Up <level, duration>, Down <level, duration> / rollback <note>
Proof: <the repository's up-down-up check>   Result: ran (<its counts line>) | not run (<why>)
Findings: <a uniqueness or lookup mismatch, a remote default database, an unmeasured Down> | none
Data test: <file> (<N> fixture rows, idempotent, resumable) | no data change
```

## Gotchas

- Room: bump the database version and add the `Migration(from, to)`
  object plus an exported schema JSON; a missing `MigrationTestHelper`
  test is a finding.
- ClickHouse has no transactional DDL; write the migration as idempotent
  statements (`IF NOT EXISTS`) and the Down as its mirror.
- Mongo migrations are code, not SQL: a versioned script that updates
  documents in batches by `_id` range, plus the validator change.
- A data test that inserts its fixtures with today's models passes
  against the new shape and proves nothing about the old rows. Fixtures
  go in as SQL at the previous revision.
- The schema diff proves structure, not content. A Down that recreates a
  dropped column with the right type passes `migrate-verify` and still
  loses every value; the data test and the header's "Down loses" cover it.
- Never run the migration against anything but the local database. Read
  the Makefile before any `make migrate*`: a target whose default
  `DATABASE_URL` or `DB_PATH` points at staging, production or a path
  outside the repository is not run, even with an override you believe
  wins, and the report names the risk.
- A freshly created migrations directory has no baseline. The first
  migration is the current schema, not the change; say so and write the
  change as the second.
