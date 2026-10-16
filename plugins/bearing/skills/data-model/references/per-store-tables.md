# data-model: per-store tables

Read when: step 5, writing the tables, collections or ClickHouse tables of each store.

5. Per store, following the reference for that store:
- Postgres: per table, in foreign-key order, the purpose, `Serves
  US-...`, expected volume with its order of magnitude (10^n) and what
  drives it, hot or not. A column table (Column, Type, Null, Key,
  Default, Description, Why): Why quotes the acceptance criterion or
  names the rule the column exists for; a column with no Why is cut.
  Ids, `timestamptz` audit columns, `NOT NULL` by default, FK with
  explicit `ON DELETE` and an index on the referencing column,
  `tenant_id` first in composite keys. Each index named
  `idx_<table>_<cols>` (unique: `uq_`) with the query it serves and the
  predicate it must repeat; partial, covering and BRIN where the
  reference says. Each CHECK named `chk_<table>_<rule>` with the bad row
  it refuses.
- MongoDB: each collection with a `$jsonSchema` validator sketch
  (`required`, `bsonType`, `maxItems`, `maxLength`,
  `additionalProperties: false`, `schemaVersion`), the embed or
  reference decision with its bound, and an index per query shape.
- ClickHouse: engine and why, `ORDER BY` with the rationale (equality
  filters first, lowest cardinality first, three to five columns),
  partition key, TTL, the version column for `ReplacingMergeTree`,
  and the materialised views with their `TO` targets.
