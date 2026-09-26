# PostgreSQL reference

Target version 16 or later. Everything below assumes a hot table is one with
writes every second or over 1M rows; a small table is anything else.

## Schema design

- Names: `snake_case`; tables are plural nouns (`invoices`); FK columns are
  `<singular>_id`; indexes `idx_<table>_<col>[_<col>]`; constraints
  `<table>_<col>_check|_fkey|_key`. Identifiers over 63 characters are
  truncated silently, so keep them under 50.
- Ids: `id uuid PRIMARY KEY DEFAULT uuidv7()` on PG18, or a v7 generated
  in the app below 18, when ids leave the system; `gen_random_uuid()` (v4)
  only on a table that stays small, because random keys scatter inserts
  across the b-tree (see the Gotchas in SKILL.md); otherwise
  `id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY`. Never `serial`,
  never an id computed by the application.
- Timestamps: `created_at timestamptz NOT NULL DEFAULT now()` and
  `updated_at timestamptz NOT NULL DEFAULT now()` set by the repository on
  every UPDATE (or a trigger, documented). `timestamp` without tz and
  `date` used for an instant are findings.
- Nullability: `NOT NULL` by default. A column is nullable only when absent
  is a real state that the code handles on read.
- Enums vs lookup tables: `CREATE TYPE ... AS ENUM` only when the set changes
  less than once a year (adding a value is a migration, removing one is a
  rewrite). Otherwise `text` plus `CHECK (status IN ('draft','sent','paid'))`,
  or a lookup table when values carry data (label, sort order, owner).
- Money: `numeric(19,4)` or `bigint` minor units with a `currency char(3)`
  column. `float`/`real`/`double precision` on money is Critical.
- Soft delete: `deleted_at timestamptz NULL`; every repository read filters
  it; hot indexes get `WHERE deleted_at IS NULL`; a uniqueness rule that must
  survive deletes becomes a partial unique index. A batched job hard-deletes
  after the retention window written in the migration header.
- Foreign keys always, with an explicit `ON DELETE`, and an index on the
  referencing column (Postgres does not create one).
- Multi-tenant: `tenant_id` first in every composite index and unique key.
- Text: `text` with a `CHECK (length(x) <= n)`; `varchar(n)` only when n is
  a business rule, because changing n is a table lock.

## Indexing

| Predicate | Index |
| --- | --- |
| `=`, `<`, `BETWEEN`, `ORDER BY`, `LIKE 'abc%'` | b-tree (default) |
| `jsonb @>`, array `&&`/`@>`, `tsvector @@` | GIN (`jsonb_path_ops` when only `@>`) |
| `LIKE '%abc%'`, `ILIKE` | GIN with `pg_trgm` |
| ranges, geometry, `EXCLUDE` constraints | GiST |
| append-only, over 10M rows, filtered by `created_at` | BRIN (1% of a b-tree) |
| `lower(email)`, `(data->>'status')` | expression index on that expression |

- Composite order: equality columns, then the `ORDER BY` column, then the
  range column. Only a leftmost prefix is usable.
- Partial index (`WHERE status = 'pending'`) for a hot subset under 10% of
  the table; the query must repeat the predicate literally.
- Covering: `INCLUDE (cols)` for the top read query; confirm with
  `Heap Fetches: 0` in `EXPLAIN (ANALYZE)`; it stays 0 only while autovacuum
  keeps the visibility map current.
- `CREATE INDEX CONCURRENTLY` on any table over 1M rows. It cannot run in a
  transaction (goose: `-- +goose NO TRANSACTION`), scans twice, and a failure
  leaves an `INVALID` index: find with `SELECT indexrelid::regclass FROM
  pg_index WHERE NOT indisvalid`, drop, retry.
- Unused: `idx_scan = 0` in `pg_stat_user_indexes` after 30 days of
  production is a drop candidate. Every index is an extra write.
- Bloat: measure with `pgstattuple`; over 30% on a hot index run
  `REINDEX INDEX CONCURRENTLY`; for tables use `pg_repack`. `VACUUM FULL`
  takes `ACCESS EXCLUSIVE` for the whole rewrite: never in production hours.

## Migrations

- Expand/contract, step by step in `migration-patterns.md`. No migration may
  break the version of the code currently running.
- First lines of every Up: `SET lock_timeout = '2s'; SET statement_timeout =
  '60s';`. On failure the deploy retries the migration, it does not raise
  the timeout. Never `lock_timeout = 0` in a migration.
- Adding a column: nullable or with a constant default (metadata-only since
  PG11); backfill in batches from a job, not the migration; then
  `ADD CONSTRAINT ... CHECK (col IS NOT NULL) NOT VALID`, `VALIDATE
  CONSTRAINT` (no exclusive lock), then `SET NOT NULL` (skips the scan when
  a valid check exists), then drop the check.
- Batched backfill: `UPDATE t SET x = ... WHERE id > $last AND id <= $last +
  5000 AND x IS NULL` in a loop, commit per batch, 50 to 200 ms pause, log
  the cursor, resumable from the last id. Watch `pg_stat_progress_vacuum`
  afterwards; a 50M-row backfill bloats the table until vacuum catches up.
- Type change on a hot table: never in place. Add the new column, dual-write
  from the code, backfill, switch reads, drop the old column. Exceptions
  that are metadata-only: `varchar(n)` to `text` or a wider `varchar`.
- Renames break running code: rename only in a contract step after every
  reader has moved, or keep a view with the old name for one release.

| Operation | Lock | Online? |
| --- | --- | --- |
| `ADD COLUMN` nullable or constant default | ACCESS EXCLUSIVE, ms | yes |
| `ADD COLUMN ... DEFAULT <volatile fn>` | ACCESS EXCLUSIVE + rewrite | no |
| `DROP COLUMN` | ACCESS EXCLUSIVE, ms (no rewrite) | yes, after readers gone |
| `ALTER COLUMN TYPE` (most) | ACCESS EXCLUSIVE + rewrite | no |
| `SET DEFAULT`, `DROP DEFAULT` | ACCESS EXCLUSIVE, ms | yes |
| `SET NOT NULL` without a valid check | ACCESS EXCLUSIVE + full scan | no |
| `ADD CONSTRAINT ... NOT VALID` | ACCESS EXCLUSIVE, ms | yes |
| `VALIDATE CONSTRAINT` | SHARE UPDATE EXCLUSIVE + scan | yes |
| `ADD FOREIGN KEY` (validating) | SHARE ROW EXCLUSIVE on both tables + scan | no; use NOT VALID |
| `CREATE INDEX` | SHARE (blocks writes) | no over 1M rows |
| `CREATE/DROP INDEX CONCURRENTLY` | SHARE UPDATE EXCLUSIVE | yes |
| `ADD PRIMARY KEY/UNIQUE ... USING INDEX` | ACCESS EXCLUSIVE, ms | yes, index built first |
| `RENAME COLUMN/TABLE` | ACCESS EXCLUSIVE, ms | breaks readers |
| `TRUNCATE`, `VACUUM FULL`, `CLUSTER` | ACCESS EXCLUSIVE + rewrite | no |
| `UPDATE` every row | ROW EXCLUSIVE, row locks, bloat | only in batches |

## Queries

- Name the columns. `SELECT *` breaks when a column is added (wider rows,
  changed struct scans) and hides what a query needs.
- Keyset pagination: `WHERE (created_at, id) < ($1, $2) ORDER BY created_at
  DESC, id DESC LIMIT 50` on an index over `(created_at, id)`. `OFFSET`
  past 10,000 rows scans and discards every row before it.
- N+1: one query per row of a parent result is a finding at any size. Use
  `WHERE id = ANY($1)` with an array, a join, or a lateral subquery.
- Reading `EXPLAIN (ANALYZE, BUFFERS)`: the outermost `actual time` is the
  cost; `Seq Scan` on a table over 100k rows in a request path is wrong;
  `rows=` estimated vs actual off by 10x means stale stats (`ANALYZE t`) or
  a correlated predicate (`CREATE STATISTICS`); `Buffers: shared read` high
  means the working set is not in cache; a `Sort` with `external merge` needs
  an index or a smaller `LIMIT`; `Nested Loop` with a large outer side is the
  N+1 in disguise.
- Which query to `EXPLAIN`: `pg_stat_statements` ordered by
  `total_exec_time` names the top ten; a query picked by guess is not a
  measurement.
- Set `statement_timeout` per role (`5s` for the API role, more for jobs) so
  one bad plan cannot hold a connection forever.
- Locking: `SELECT ... FOR UPDATE SKIP LOCKED` for queues; `FOR NO KEY
  UPDATE` when only the row's non-key data changes so FK inserts on child
  tables are not blocked.
- Upsert: `INSERT ... ON CONFLICT (key) DO UPDATE SET ... WHERE t.x IS
  DISTINCT FROM EXCLUDED.x` so unchanged rows are not rewritten.

## Transactions and isolation

- Default `READ COMMITTED`. Use `REPEATABLE READ` for multi-statement reports
  that must see one snapshot; `SERIALIZABLE` for invariants across rows
  (balances, stock) with a retry loop on SQLSTATE `40001` (3 attempts,
  jittered backoff). Under `READ COMMITTED`, a check-then-write is a race.
- Lock rows in a fixed order (by id ascending) in every code path; a
  deadlock (`40P01`) means two paths disagree on the order.
- A transaction holds no lock across an HTTP call, a queue publish or a
  sleep. Set `idle_in_transaction_session_timeout = '30s'` on the role.
- Advisory locks (`pg_advisory_xact_lock(hashtext($1))`) for "one worker per
  key" instead of a lock table.

## Connection pooling

- One `pgxpool`/`asyncpg` pool per process, size 5 to 20; total across
  processes stays under `max_connections` minus 20. Postgres degrades past a
  few hundred active connections; pgbouncer in front when it does.
- pgbouncer `transaction` mode is the default choice. It breaks anything
  session-scoped: `SET` (use `SET LOCAL` inside the transaction), `LISTEN`,
  session advisory locks, temp tables, cursors held across transactions,
  and server-side prepared statements unless pgbouncer is 1.21 or newer with
  `max_prepared_statements > 0` (else pgx `QueryExecModeSimpleProtocol` or
  asyncpg `statement_cache_size=0`). `session` mode only for migrations and
  admin tools. `statement` mode never.

## JSONB

- For attributes that genuinely vary per row (integration payloads, user
  metadata). Any key that every row has and any query filters on becomes a
  real column; a `jsonb` column that stores the whole entity is Mongo in
  disguise and a finding.
- Index a filtered key with an expression index `((data->>'status'))`, or
  the column with GIN `jsonb_path_ops` when queries use `@>`.
- An update rewrites the whole value (TOAST above 2 KB); keep documents
  under 100 KB and never append to an array in JSONB in a loop.
- Validate the shape at the boundary (Zod, Pydantic) and, when the shape is
  fixed, with a `CHECK (jsonb_typeof(data->'items') = 'array')`.

## Row-level security

- For tenant isolation: `ALTER TABLE t ENABLE ROW LEVEL SECURITY; ALTER TABLE
  t FORCE ROW LEVEL SECURITY;` with a policy on
  `tenant_id = (SELECT current_setting('app.tenant_id', true)::uuid)`; the
  scalar subquery is evaluated once per statement, not once per row, and
  `tenant_id` leads an index so the policy is an index condition. The service
  runs `SET LOCAL app.tenant_id = $1` at the start of every transaction (this
  works under pgbouncer transaction mode). The API role is never the table
  owner or a superuser: both bypass RLS unless `FORCE` is on. RLS is defence
  in depth; every repository still filters by `tenant_id` explicitly.
- A `SECURITY DEFINER` function used by a policy bypasses RLS on what it
  reads: it lives in a schema the API role cannot call directly, sets
  `search_path = ''`, and has `EXECUTE` revoked from `PUBLIC`.

## Roles

- Migrations run as the owner role; the API role is a separate login with
  `SELECT, INSERT, UPDATE, DELETE` granted on named tables and `USAGE` on
  their sequences, no DDL, no `ALL PRIVILEGES`. `REVOKE ALL ON SCHEMA
  public FROM PUBLIC` in the first migration. A reporting role gets
  `SELECT` only.

## Backups and PITR

- Continuous WAL archiving plus a daily base backup (managed: automated
  snapshots with PITR on), retention 30 days, RPO 5 minutes, RTO measured.
- A restore drill every quarter into a scratch instance, with the date and
  duration recorded in the runbook. A backup that has not been restored is
  a hope. `pg_dump` is for logical copies and seeds, not the backup.
- Before a destructive migration on a table over 1M rows: a named snapshot
  or `CREATE TABLE t_backup_YYYYMMDD AS SELECT ...`, dropped one week later.

## Sync to ClickHouse via CDC

- `wal_level = logical`, a publication per set of tables, `REPLICA IDENTITY
  DEFAULT` (primary key) or `FULL` for tables whose deletes must carry the
  old row. Consumer: ClickPipes/PeerDB, or Debezium into Kafka into a
  ClickHouse Kafka engine table.
- A stalled consumer keeps WAL forever. Set `max_slot_wal_keep_size = '20GB'`
  and alert on `pg_replication_slots.wal_status <> 'reserved'`.
- The ClickHouse side is `ReplacingMergeTree(_version)` with an `_deleted`
  flag; see `clickhouse.md`. Reports read from ClickHouse, never from a
  Postgres replica with a 40-second analytical query.
