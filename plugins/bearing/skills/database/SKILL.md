---
name: database
description: 'Conventions for PostgreSQL, ClickHouse and MongoDB: store choice, schema, indexes, query review, lock-safe migrations. Use when "designing a schema", "choosing an index", "reviewing a query" or "which database".'
allowed-tools: Read, Grep, Glob, Skill
---

# database

The deep reference for data on this standard. No scaffold lives here: the stack
skills (`bearing-backend:go`, `bearing-backend:python`,
`bearing-backend:node`) own the driver, the migration
tool and the Makefile targets. This skill owns what the schema, the migration, the index
and the query must look like in any of them.

## Inputs

- No prerequisites. The skill reads the schema, migrations and queries
  as they are in the repository, in any stack, scaffolded or not.
- Store in use: `DATABASE_URL`, the driver import or the migrations
  folder; if none, asks which store the feature targets, one question.
- Migration tool: the repository's (goose, Alembic, drizzle-kit, Prisma,
  migrate, Flyway, a Mongo script); if none, `db-migration` is a suggestion and the recipe
  in `references/migration-patterns.md` is written as plain SQL or a
  script for the user to apply.
- Measurements for rule 10: the user runs the `EXPLAIN` and pastes the
  output; without it the finding stays open, never assumed closed.
- References in this skill: `references/store-choice.md` (which store
  a feature belongs in), `references/postgres.md` (schema, indexes,
  lock-safe migrations, queries, isolation, pgbouncer, JSONB, RLS,
  roles, backups, CDC), `references/clickhouse.md` (engines, `ORDER BY`,
  partitions, TTL, dedup, mutations, batching, projections),
  `references/mongodb.md` (validators, modelling, ESR indexes,
  transactions, pagination, lazy migration), and
  `references/migration-patterns.md` (expand and contract per store,
  testing a Down, the header template); `references/review-checklist.md`
  is what `branch-review` applies.

## When this skill is active

- Touching `migrations/`, `*.sql`, `repository/`, `db/`, a Mongo validator
  or model, a ClickHouse DDL or a Kafka/CDC pipeline: read the matching
  reference once per session, then work.
- `db-migration <name>`: paste the header block and follow the recipe in
  `references/migration-patterns.md`. A migration without the header is
  incomplete.
- `branch-review` on a diff touching those paths: apply
  `references/review-checklist.md` and report in the reviewer format.
- A new feature needs a store: read `references/store-choice.md` and run
  `tech-decision` for the `database` or `analytics store` key. Any choice
  other than Postgres gets an ADR (`adr`) in the same MR.
- Pack skill: `supabase-postgres-best-practices`, when installed, is
  loaded with the Skill tool only when the database is Supabase (policies
  on `auth.uid()`, the `anon` and `authenticated` roles, tables exposed
  through the Data API). Elsewhere its rules are a subset of
  `references/postgres.md`, which wins where they differ: versioned
  migrations with a tested Down, not its idempotent `DO` blocks; native
  `uuidv7()` on PG18, not the `pg_uuidv7` extension; timeouts set on the
  role, not with `ALTER SYSTEM`. Pack not installed: nothing changes.

## Layout

Where data code lives in each stack skill's layout; this skill owns the
content of these files, the stack skill owns the tool.

```
db/migrations/            goose (Go), knex, ClickHouse: NNNN_name.sql, Up and Down
db/queries/               sqlc query files (Go)
alembic/versions/         Alembic (Python), NNNN_name.py, upgrade and downgrade
drizzle/                  drizzle-kit (Node, node): NNNN_name.sql generated from src/db/schema.ts
drizzle/down/             hand-written Down for each drizzle/NNNN_name.sql (drizzle-kit has none)
drizzle/meta/             drizzle-kit journal and snapshots; generated, never edited
src/db/schema.ts          Drizzle tables (Node); repositories are the only place queries live
prisma/migrations/        Prisma (TypeScript, foreign layouts)
internal/store/           Go repositories (sqlc output plus hand-written)
app/db/repositories/      Python repositories, the only place SQL lives
app/db/models.py          SQLAlchemy models
db/migrations/*.js        Mongo migration scripts (batched by _id range)
```

## On a foreign layout

Hard rules anywhere: 1, 2, 3, 7, 8 and 9 below, and an index decision
for every new query shape. Advisory: the directories above, the
migration tool (Flyway, migrate, dbmate stay where they are; the header
block and the Up, Down, Up test still apply), the repository pattern's
exact shape. Say which rule was relaxed and why.

## Rules that matter most

1. Every schema change is a migration file in the repo with a Down that CI
   runs (`up`, `down`, `up`). Mongo validator and index changes and
   ClickHouse DDL included. Nothing is applied from a shell by hand.
2. Ids are `uuid` v7 (`uuidv7()` as a default on PG18, generated in the
   app below it; v4 `gen_random_uuid()` only on small tables) or
   `bigint GENERATED ALWAYS AS IDENTITY`;
   `ObjectId` in Mongo; `UUID` or the source id in ClickHouse. Never an
   integer the application computes.
3. Time is `timestamptz` in Postgres, `DateTime64(3, 'UTC')` in ClickHouse,
   BSON `Date` in Mongo. Never a string, never a naive local time. Local
   time exists only in the presentation layer.
4. Every new query shape (`WHERE`, `ORDER BY`, `$match`, `$sort`) has an
   index decision written in the migration header: which index serves it,
   or why none is needed. "Postgres will figure it out" is not a decision.
5. Repositories own the driver. A service never sees a row, a cursor, a
   `pgx.Rows`, a BSON document or a ClickHouse block.
6. Transactions open and close in the service around one unit of work, hold
   locks under 1 second, and make no network call while open.
7. Columns are named in every read: no `SELECT *`, no `find()` without a
   projection, no `SELECT *` from a wide ClickHouse table.
8. Parameterised only. A string-built query, a user-controlled Mongo operator
   (a key starting with `$`), or an interpolated ClickHouse identifier is a
   Critical finding.
9. Anything touching more than 10,000 rows runs in batches of 1,000 to
   10,000 keyed by primary key, resumable, rate-limited, logged with
   progress, and outside the migration transaction.
10. Nothing is optimised without a measurement: `EXPLAIN (ANALYZE, BUFFERS)`,
    `explain("executionStats")`, `EXPLAIN indexes = 1` plus
    `system.query_log`. An index or a denormalisation with no query behind
    it is a finding.

## Commands

Each target is used when the Makefile has it; the command after the
colon is the native form. Nothing here runs against anything but the
local database.

```
make migrate          # goose up | alembic upgrade head | drizzle-kit migrate | prisma migrate deploy
make migrate-down     # goose down | alembic downgrade -1 | psql drizzle/down/<last>.sql | the tool's rollback
make migrate-verify   # up, down, up: proves the Down (db-migration adds it)
make sqlc             # sqlc generate (Go)
psql "$DATABASE_URL" -c 'EXPLAIN (ANALYZE, BUFFERS) <query>'   # the measurement rule 10 needs
clickhouse-client --query 'EXPLAIN indexes = 1 <query>'
mongosh --eval 'db.<coll>.find(<q>).explain("executionStats")'
```

## Gotchas

- **The Postgres lock queue.** `ALTER TABLE` waits for `ACCESS EXCLUSIVE`
  behind one long `SELECT`, and every statement issued after it, reads
  included, queues behind the `ALTER`. A 20 ms migration becomes a full
  outage. Every migration starts with `SET lock_timeout = '2s'` and retries.
- **Drizzle migrations.** `drizzle-kit migrate` applies every pending file
  in one transaction and has no Down. So `CREATE INDEX CONCURRENTLY` cannot
  ship in a Drizzle file (run it from a release job with the header, then
  let the next generated file carry it with `IF NOT EXISTS`), and the Down
  is a hand-written `drizzle/down/NNNN_name.sql`. The header and the `SET`
  lines are prepended to the generated SQL; the statements stay as
  drizzle-kit wrote them, and `drizzle/meta` is never edited. The Down test
  applies the down file with `psql`, deletes the newest row of
  `drizzle.__drizzle_migrations`, and migrates up again.
- **ClickHouse mutations.** `ALTER TABLE ... UPDATE/DELETE` rewrites every
  part it touches, runs asynchronously, and a queue of them starves merges
  until inserts fail with "Too many parts". Correct data by inserting a
  higher version into a `ReplacingMergeTree`, by TTL, or by `DROP PARTITION`.
- **Mongo unbounded arrays.** `$push` into a document that grows with usage
  rewrites the whole document and every index over the array on each write,
  then hits the 16 MB limit and the writes stop. Cap with `$slice`, bucket,
  or make it a collection.
- **Timezone drift.** `timestamp` without tz stores wall-clock in the
  session's timezone; ClickHouse `DateTime` with no zone uses the server's;
  a driver handed a local `Date` shifts by the client offset. Check
  `SHOW timezone`, `SELECT timezone()` and the driver config before trusting
  any date in a report.
- **Ids generated in the app.** `max(id) + 1` races under two concurrent
  inserts and produces a duplicate key at 3 a.m.; random UUID v4 on a
  100M-row table scatters inserts across every b-tree leaf and doubles the
  index size. Identity columns or UUID v7.
- **Idle in transaction.** A pool of 20 connections is gone in seconds when
  a handler opens a transaction and calls an HTTP API inside it. Set
  `idle_in_transaction_session_timeout = '30s'` on the role.
