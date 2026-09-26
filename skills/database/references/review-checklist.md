# Database review checklist

For each item, find the concrete failure (input or state, and what the user
or operator sees) or write "none found". Report in the reviewer format.
A migration without the `migration-patterns.md` header is a Medium finding.

## Every store
- A schema change without a migration file, or a migration without a Down,
  or a Down that is not run by a test. Drizzle: a generated
  `drizzle/NNNN_name.sql` with no `drizzle/down/NNNN_name.sql`, a hand edit
  to `drizzle/meta`, or `CREATE INDEX CONCURRENTLY` inside a Drizzle file
  (drizzle-kit runs pending files in one transaction, where it fails).
- A migration that breaks the code version currently deployed (rename, drop,
  type change, `NOT NULL` on a column the old code does not write).
- A new `WHERE`, `ORDER BY`, `$match` or `$sort` shape with no index decision
  in the header, or a decision that names an index whose column order does
  not serve the predicate.
- Application-generated integer ids; a string or naive timestamp; a float
  on money.
- A repository returning a driver type (rows, cursor, BSON) to a service; a
  transaction opened inside a repository; a network call inside a
  transaction.
- A string-built query, an interpolated identifier, a `$`-prefixed key
  reaching a Mongo query from input.
- `SELECT *`, `find()` without a projection, an N+1 loop.
- A statement over more than 10,000 rows run in one go instead of batches.
- PII in a new column or field with no note on retention or encryption.

## Postgres
- DDL without `SET lock_timeout` at the top of the Up.
- `ADD COLUMN ... NOT NULL` without a default on a populated table; a
  volatile default on a hot table; `SET NOT NULL` without a prior validated
  check; a validating `ADD FOREIGN KEY` on a hot table.
- `CREATE INDEX` without `CONCURRENTLY` on a table over 1M rows, or
  `CONCURRENTLY` inside a transaction.
- `ALTER COLUMN TYPE` in place on a hot table; `VACUUM FULL`; `TRUNCATE`
  in a migration.
- A backfill `UPDATE` inside the migration, or one with no resumable cursor.
- `timestamp` without tz; `serial`; `varchar(n)` where n is not a rule.
- A FK column without an index; a unique key that ignores `deleted_at`
  under soft delete; `tenant_id` missing from a composite index or key.
- `OFFSET` on an unbounded list; `FOR UPDATE` without `SKIP LOCKED` on a
  queue table; a check-then-write under READ COMMITTED guarding an invariant.
- Session state (`SET`, session advisory lock, `LISTEN`, prepared
  statements) under pgbouncer transaction mode.
- A `jsonb` column that holds the whole entity or a key every query filters
  on without an expression index.
- An RLS policy calling a function per row instead of through a scalar
  `(SELECT ...)`; a `SECURITY DEFINER` function without `search_path = ''`
  or callable by the API role; an API role that owns tables, holds DDL or
  was granted `ALL PRIVILEGES`.

## ClickHouse
- `ORDER BY` beginning with the timestamp, or not covering the equality
  filters of the listed queries; more than five key columns.
- `PARTITION BY` on a high-cardinality column; no TTL or retention stated.
- `ReplacingMergeTree` with no version column, or a version that is not
  monotonic; a read that relies on merges having happened.
- `FINAL` or `OPTIMIZE ... FINAL` in a request path or a cron on a large
  table; `ALTER ... UPDATE/DELETE` issued from application code.
- Single-row inserts from a handler; a batch that spans over 100
  partitions; a client-side buffer with no crash safety.
- `Nullable` on a key column; `String` where `LowCardinality(String)` or
  `DateTime64` belongs; a JSON string queried with `JSONExtract` per row.
- A materialised view without `TO` or without a backfill of existing rows;
  an MV reading another MV's target and expecting merged data.
- DDL that is not idempotent or lacks `ON CLUSTER`; a function on a key
  column in a `WHERE`; the big table on the right of a `JOIN`.
- A Kafka engine table queried directly, or a pipeline with no lag alert.

## MongoDB
- A collection with no `$jsonSchema` validator, or one with
  `validationAction: 'warn'`, or arrays without `maxItems`.
- An array that grows with usage (`$push` with no `$slice`, a list of events
  or messages inside a parent document).
- A query shape with no index, or a compound index whose order breaks ESR;
  a `COLLSCAN` or `totalDocsExamined / nReturned > 10` in explain output.
- A multi-document transaction on a normal request path; a transaction with
  a network call or more than 1,000 writes.
- `w: 0`, `readPreference: secondary` on a read-your-writes path.
- `skip()` pagination past 10,000; `$lookup` without an index on the foreign
  field; `$unwind` on an unbounded array; `allowDiskUse` in a request path.
- `updateMany({})` over a whole collection; a schema change with no
  `schemaVersion` bump or no dual-read period.
- `$where` or server-side JavaScript; `root` or `--noauth` in a connection
  string or compose file; a change stream that does not persist its token.
