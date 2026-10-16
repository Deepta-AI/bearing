# data-model: per-store tables, enumerations, retention and the migration plan

Read when: steps 5 to 7: the per-store detail, the closed sets, retention and the migration order.

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
6. Enumerations: one row per enum with its values and why the set is
closed. Retention: one row per table with a lifetime, its rule and the
mechanism that enforces it (batched hard delete, TTL, partition drop).
A lifetime no story, PRD or policy states is `UNDEFINED`, with an owner
question; a number you would suggest goes in that question, never in
the lifetime cell and never into a purge job, TTL or partition scheme.
Then the personal-data columns, each with its kind.
7. Migration plan in order, each item named and numbered the way the
repository's existing migrations are (next free number, same tool and
file style; claim no convention the repository does not have), with
its lock risk on a hot table, the batch note, and the expand, migrate
or contract phase it belongs to; `db-migration` writes them later.
The plan writes no migration file. A new database is migration 1:
`schema.sql`.
