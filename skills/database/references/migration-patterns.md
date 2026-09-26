# Migration patterns

Every schema change ships in three deploys, or the header says why fewer:
expand (add; both code versions work), migrate (backfill, switch readers),
contract (drop the old shape). One file per step, each with the header below.

## Postgres: replace `invoices.state` (enum) with `status` (text)

Expand, deploy 1. Code writes both columns and still reads `state`:

```sql
-- +goose Up
SET lock_timeout = '2s';
SET statement_timeout = '60s';
ALTER TABLE invoices ADD COLUMN status text;
ALTER TABLE invoices ADD CONSTRAINT invoices_status_check
  CHECK (status IN ('draft', 'sent', 'paid', 'void')) NOT VALID;
-- +goose Down
ALTER TABLE invoices DROP COLUMN status;
```

Backfill: a job after deploy 1, never inside the migration, resumable:

```sql
UPDATE invoices SET status = lower(state::text)
WHERE id > $1 AND id <= $2 AND status IS NULL;  -- 5,000 ids per batch
-- commit, sleep 100 ms, log $2, repeat until max(id)
```

Index for the new read shape, its own file, outside a transaction:

```sql
-- +goose NO TRANSACTION
-- +goose Up
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_invoices_tenant_status
  ON invoices (tenant_id, status) WHERE deleted_at IS NULL;
-- +goose Down
DROP INDEX CONCURRENTLY IF EXISTS idx_invoices_tenant_status;
```

Migrate, deploy 2: code reads `status`, still writes both. Contract, deploy
3, one release after the last reader of `state` is gone:

```sql
-- +goose Up
SET lock_timeout = '2s';
ALTER TABLE invoices VALIDATE CONSTRAINT invoices_status_check;
ALTER TABLE invoices ADD CONSTRAINT invoices_status_nn
  CHECK (status IS NOT NULL) NOT VALID;
ALTER TABLE invoices VALIDATE CONSTRAINT invoices_status_nn;
ALTER TABLE invoices ALTER COLUMN status SET NOT NULL;
ALTER TABLE invoices DROP CONSTRAINT invoices_status_nn;
ALTER TABLE invoices DROP COLUMN state;
-- +goose Down
ALTER TABLE invoices ALTER COLUMN status DROP NOT NULL;
ALTER TABLE invoices ADD COLUMN state invoice_state;  -- values not restored
```

## ClickHouse equivalent

- Add: `ALTER TABLE events ON CLUSTER main ADD COLUMN IF NOT EXISTS status
  LowCardinality(String) DEFAULT ''`; metadata only, old parts read the
  default. If old parts must hold real values: one `ALTER ... UPDATE status
  = lower(state) WHERE status = ''`, off-peak, watched in `system.mutations`.
- Drop: `ALTER TABLE events ON CLUSTER main DROP COLUMN IF EXISTS state`
  after every reader and every MV referencing it has moved.
- Key change: `CREATE TABLE events_v2 ... ORDER BY (tenant_id, status, ts)`;
  point the MVs at both; `INSERT INTO events_v2 SELECT ... FROM events`
  partition by partition; `EXCHANGE TABLES events AND events_v2 ON CLUSTER
  main`; drop the old table a week later. Down is the reverse `EXCHANGE`.

## MongoDB equivalent

- Expand: `collMod` the validator to `oneOf` both shapes keyed on
  `schemaVersion`; `createIndex` for the new shape; code reads both and
  writes `schemaVersion: 2`.
- Migrate: on read, upgrade a v1 document and write it back with
  `updateOne({ _id, schemaVersion: 1 }, ...)` (the filter prevents a lost
  update); a job walks `_id` ranges in batches of 1,000 with a pause until
  `countDocuments({ schemaVersion: 1 })` is 0.
- Contract: `collMod` to the v2 shape only; `hideIndex` the old index for a
  week, then `dropIndex`; remove the v1 read path. Down restores the v1
  validator and unhides the index; v2 data is not converted back.

## Testing a Down

- CI, on a fresh database: `up` all, dump the schema to A, `down` one, `up`
  one, dump to B, fail on `diff A B`. Postgres: `pg_dump --schema-only`;
  Mongo: `listCollections` (validators) plus `getIndexes()`; ClickHouse:
  `SHOW CREATE TABLE` per table.
- Drizzle (Node): drizzle-kit is forward-only, so the Down is
  `drizzle/down/NNNN_name.sql`. The test applies it with `psql`, deletes
  the newest row of `drizzle.__drizzle_migrations` so the file counts as
  unapplied, then runs `drizzle-kit migrate` again before the second dump.
- A Down that loses data says so in the header ("Down loses: ...") and the
  reviewer checks nothing in production depends on it before a rollback.
- The scaffolds ship this as `make migrate-verify` with
  `scripts/schema-snapshot.sql` (columns, indexes, constraints, enums,
  views, triggers, policies, one sorted line each), and run it in the CI
  integration job. It runs the newest Down, then every Down, and diffs
  each time.

## Testing a data change

The schema diff says nothing about the rows. Any migration or backfill
that rewrites existing data gets a test that starts from the old shape:

1. Migrate to the revision before the change (`goose up-to <n-1>`,
   `alembic upgrade <prev>`, drizzle: apply the files up to the previous
   one).
2. Insert literal fixtures in SQL, never through the application's models:
   an ordinary row, NULLs, empty strings, the longest value, non-ASCII,
   the duplicate a new unique constraint must resolve, a soft-deleted row,
   a row from a second tenant.
3. Apply the change. Assert each fixture's new value by its key, and the
   count: `SELECT count(*)` before and after, equal unless the header says
   rows are merged or removed, and then by exactly that number.
4. Backfill jobs: run twice, assert the second run changes nothing; stop
   after one batch, run again, assert every row is done once.
5. Run the Down. Assert what "Down loses" names is the only difference.

```python
# tests/integration/test_0007_split_name.py
def test_0007_splits_full_name(alembic_at, db):
    alembic_at("0006")                        # the shape before the change
    db.execute(text("""INSERT INTO users (id, full_name) VALUES
        (1, 'Ada Lovelace'), (2, NULL), (3, ''), (4, 'Zoë  de la Cruz')"""))
    alembic_at("0007")
    rows = dict(db.execute(text("SELECT id, first_name || '|' || last_name FROM users")).all())
    assert rows == {1: "Ada|Lovelace", 2: None, 3: "|", 4: "Zoë|de la Cruz"}
```

In production the same check is a parity query in the runbook, run
before the contract phase: the count of rows still in the old shape is
zero (`WHERE first_name IS NULL AND full_name IS NOT NULL`).

## The index decision comment

One entry per new query shape, in the header: the predicate as the
repository writes it, the index that serves it, the rejected alternative.

```
-- Index: idx_invoices_tenant_status (tenant_id, status) WHERE deleted_at IS NULL
--   serves: store.ListInvoicesByStatus  WHERE tenant_id = $1 AND status = $2 AND deleted_at IS NULL
--   rejected: (status) alone, cardinality 4, planner would seq scan
```

## Header template (`db-migration` pastes it at the top of every file)

```
-- Migration: 00042_invoices_add_status        Task: PROJ-123
-- Store: postgres | clickhouse | mongodb      Phase: expand | migrate | contract (1 of 3)
-- Purpose: one sentence, what changes and why
-- Locks: ACCESS EXCLUSIVE on invoices, metadata only, under 100 ms, lock_timeout 2s
-- Rows: invoices ~4.2M; backfill by job in batches of 5,000 (not in this file)
-- Index: <one entry per query shape as above, or "none: no new shape">
-- Retention / PII: <TTL or retention window | none>; <field: encrypted with KMS key | no PII>
-- Down: what it reverts; Down loses: <data or "nothing">; tested in: <CI job or test file>
```

Mongo files use `//` for the block. `Locks` is "n/a" for ClickHouse and
Mongo; `Rows` still states the volume and the batch plan.
