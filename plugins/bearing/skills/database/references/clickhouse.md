# ClickHouse reference

Target version 24.x or later, one cluster with replication (`Replicated*`
engines via `ON CLUSTER`) in every environment past local. ClickHouse holds
immutable facts; the truth stays in Postgres.

## Engines and when

| Engine | Use | Not for |
| --- | --- | --- |
| `MergeTree` | append-only events, logs, metrics | anything updated later |
| `ReplacingMergeTree(version)` | CDC copies of Postgres rows, latest state per key | counters |
| `AggregatingMergeTree` | pre-aggregates fed by a materialised view (`-State`) | raw rows |
| `SummingMergeTree` | additive counters only, all non-key columns summed | anything with a string payload |
| `Kafka` | ingestion source, always with an MV to a MergeTree | direct queries |

- `ReplacingMergeTree(version)`: the version column is monotonic per key
  (`updated_at` as `DateTime64`, or the CDC LSN). Without one, "last
  inserted wins" is undefined across parts. Add `_deleted UInt8` and filter
  `WHERE _deleted = 0` in every read; `is_deleted` as the second engine
  argument (24.x) lets merges drop them.
- Materialised views are insert triggers: they see only the inserted block,
  never past rows, never merges. Always `TO target_table` (never implicit
  storage), and backfill with `INSERT INTO target SELECT ... FROM source`
  after creating it. Aggregates in an MV use `-State` functions into an
  `AggregatingMergeTree` and are read with `-Merge`.
- Replicated engines dedupe identical insert blocks for the last 1,000
  blocks (`replicated_deduplication_window`); a retried batch is safe if it
  is byte-identical. Non-replicated tables dedupe nothing by default.

## ORDER BY and PRIMARY KEY

- `ORDER BY` is the sparse index. Design it for the reads: equality filters
  first, lowest cardinality first (`tenant_id`, then `event_name`, then
  `ts`). Three to five columns. A key that starts with `ts` serves only time
  scans and forces a full read for every tenant query.
- `PRIMARY KEY` defaults to the whole `ORDER BY`; declare a prefix when the
  tail columns exist only to place rows for the engine (dedup key for
  Replacing, summation key for Summing) and would bloat the index in RAM.
- A granule is 8,192 rows; a point lookup reads at least one whole granule,
  which is why millisecond lookups belong in Postgres.
- Changing `ORDER BY` after the fact means a new table: create, `INSERT
  SELECT`, `EXCHANGE TABLES`, drop. Get it right from the query list.

## Partitioning and TTL

- `PARTITION BY toYYYYMM(ts)` (or `toDate(ts)` above ~100M rows a day). Never
  by a high-cardinality column (`tenant_id`, `user_id`): a partition per
  tenant means thousands of parts and inserts fail at `parts_to_throw_insert`
  (a per-partition cap on active parts).
- Keep the total under 1,000 partitions per table. `DROP PARTITION` is the
  only free delete; design retention around it.
- `TTL ts + INTERVAL 90 DAY DELETE` with `ttl_only_drop_parts = 1` so expiry
  drops whole parts instead of rewriting them. `TTL ... TO VOLUME 'cold'`
  for tiered storage. The TTL is stated in the migration header.

## Deduplication is designed

- Exact replays: replicated block dedup (above) plus an idempotent producer
  that resends the same batch. Or `insert_deduplication_token` per batch.
- Logical duplicates (same `event_id` twice): `ReplacingMergeTree` keyed on
  `(tenant_id, event_id)` plus a read-side pattern; or a dedup step in the
  pipeline keyed on `event_id` over a 24-hour window. Say which in the DDL
  comment. "Merges will sort it out eventually" is not a design.
- Read-side without `FINAL`: `SELECT key, argMax(col, version) ... GROUP BY
  key`, or `LIMIT 1 BY key` after `ORDER BY version DESC`.

## Mutations and FINAL

- `ALTER TABLE ... UPDATE/DELETE` is a mutation: asynchronous, rewrites every
  part containing a matching row, visible in `system.mutations`. One per
  week for a GDPR erasure is fine; one per request is an outage. Lightweight
  `DELETE FROM` still rewrites a mask column and is not free.
- To correct data: insert a new version (Replacing), let TTL expire it, or
  drop the partition and reload.
- `FINAL` merges at read time and costs 2 to 10x. Allowed in a nightly job or
  a dashboard with under 1 query per second, never in an API path. Set
  `do_not_merge_across_partitions_select_final = 1` when it is used.

## Inserts

- One insert per second per table with 10,000 to 500,000 rows. One-row
  inserts create one part each and hit "Too many parts" within minutes.
- From request handlers, `async_insert = 1, wait_for_async_insert = 1`
  (server-side batching, ack after flush) rather than a client-side buffer
  that loses rows on crash. `Buffer` engine tables are legacy.
- `max_partitions_per_insert_block = 100`: a batch spanning more partitions
  is a backfill and goes partition by partition.

## Types

- `LowCardinality(String)` for any string under 10,000 distinct values
  (`event_name`, `country`, `status`); 3 to 10x smaller and faster to group.
- `DateTime64(3, 'UTC')` for instants, `Date` for days. `DateTime` without a
  zone takes the server zone. Never a `String` timestamp.
- `Nullable(T)` adds a mask file per column, disables the sparse index on
  that column and slows every read. Use a sentinel (`0`, `''`,
  `toDateTime64(0, 3)`) and document it; `Nullable` only when absence must
  be distinguishable and the column is never in a key.
- `UInt8/16/32/64` at the smallest fitting width; `Decimal(18, 4)` for
  money; `UUID`; `IPv4`/`IPv6`; `Enum8` only for sets that never change
  (adding a value is an `ALTER`); `Array(T)` and `Map(K, V)` are fine when
  bounded; a JSON blob as `String` is queried with `JSONExtract*` and is a
  finding above one key per query (add columns via MV).

## Projections and skip indexes

- A projection is a second `ORDER BY` (or a pre-aggregate) kept inside the
  table and chosen by the planner. One per alternative access path (e.g.
  `user_id, ts` on a table ordered by `tenant_id, event_name, ts`).
  `ALTER TABLE ... MATERIALIZE PROJECTION` backfills it as a mutation.
- Skip indexes: `minmax` for a column correlated with the sort order,
  `set(100)` for low-cardinality columns, `bloom_filter` or `tokenbf_v1` for
  equality/`hasToken` on strings, `ngrambf_v1` for `LIKE '%x%'`. They
  help only when matching rows cluster within granules; verify with `EXPLAIN
  indexes = 1` that granules are actually skipped.

## Query anti-patterns

- `SELECT *` from a wide table: every column is a file read.
- A function on a key column in `WHERE` (`toDate(ts) = today()`): write the
  range on the raw column (`ts >= today() AND ts < today() + 1`).
- `JOIN` with the big table on the right: the right side is loaded into
  memory. Small dictionary on the right, or use `dictGet` from a
  `Dictionary`.
- `ORDER BY` without `LIMIT` over millions of rows; `count(DISTINCT x)` where
  `uniq(x)` (approximate, 1%) or `uniqExact` is meant.
- `GROUP BY` on a high-cardinality key without `max_bytes_before_external_
  group_by` set: memory limit exceeded at 3 a.m.
- Check `system.query_log` for `read_rows` vs `result_rows`: over 1,000:1 in
  a hot query means the `ORDER BY` does not serve it.

## Schema migrations

- No transactional DDL: every statement is idempotent (`CREATE TABLE IF NOT
  EXISTS`, `ADD COLUMN IF NOT EXISTS`, `DROP ... IF EXISTS`) and the file is
  safe to re-run after a partial failure. `ON CLUSTER` on every DDL.
- Cheap: `ADD COLUMN` (metadata; old parts read the default), `DROP COLUMN`,
  `MODIFY TTL`, `ADD INDEX`, `ADD PROJECTION`. Expensive (mutation):
  `MODIFY COLUMN type`, `MATERIALIZE INDEX/PROJECTION`, `UPDATE`, `DELETE`.
  Impossible in place: `ORDER BY`, `PARTITION BY`, engine (new table).
- Migrations are versioned SQL files applied by the same runner as Postgres
  (golang-migrate with the clickhouse driver, or the repo's runner) into a
  `schema_migrations` table on the cluster. A Down for a table is `DROP`;
  for a column it is `DROP COLUMN` with the data loss stated in the header.

## Ingestion

- From Postgres: CDC (ClickPipes/PeerDB, or Debezium into Kafka) into
  `ReplacingMergeTree(_version)` with `_deleted`; see `postgres.md` for the
  slot and `REPLICA IDENTITY` rules. Never a cron `SELECT *` copy past 1M
  rows.
- From Kafka: a `Kafka` engine table (`kafka_format = 'JSONEachRow'`,
  `kafka_num_consumers` = partitions / replicas), one MV per target,
  `kafka_handle_error_mode = 'stream'` with a second MV writing `_error`
  rows to a dead-letter table. The Kafka table itself is never queried.
- Every pipeline has a lag metric (`system.kafka_consumers` or the CDC
  tool's) with an alert at 5 minutes, and a row-count reconciliation against
  the source once a day.
