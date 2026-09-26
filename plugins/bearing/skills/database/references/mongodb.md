# MongoDB reference

Target version 7 or later, always a replica set (three members in every
environment past local; a single `mongod` has no transactions, no change
streams and no majority writes).

## Validators on every collection

- `db.createCollection(name, { validator: { $jsonSchema: ... },
  validationLevel: 'strict', validationAction: 'error' })`. A collection
  created implicitly by a first insert has no validator and is a finding.
- The schema lists `required`, a `bsonType` for every field, `enum` for
  discriminators, `maxItems` on every array, `maxLength` on strings, and
  `additionalProperties: false` at the top level.
- Changes go through `collMod` in a migration file. During a lazy migration
  the validator accepts both schema versions via `oneOf` keyed on
  `schemaVersion`.
- The application's type (Zod, Pydantic, Go struct) is generated from or
  checked against the same schema in a test; two definitions drift.

## Document modelling

- Embed when the child is read with the parent every time, is owned by it,
  and is bounded: under 100 items and under 100 KB per document. The 16 MB
  limit is the crash, 1 MB is already slow (every update rewrites the
  document and each index over it).
- Reference (`ObjectId` in a field, joined by a second query or `$lookup`)
  when the child is queried alone, updated independently, or unbounded.
- Unbounded means it grows with usage: messages, events, audit entries,
  sessions. Those are collections. Cap a recent-items array with
  `$push: { items: { $each: [...], $slice: -50 } }` and state the bound in
  the validator.
- Bucket pattern for time series: one document per (key, hour or day) with
  an array bounded by the bucket size, or a native time-series collection
  (`timeseries: { timeField, metaField, granularity }`) which also handles
  TTL and compression.
- Outlier pattern: the 1% of documents that would exceed the bound get
  `hasOverflow: true` and their tail in an overflow collection; the code
  checks the flag.
- Every document carries `schemaVersion: <int>`, `createdAt`, `updatedAt`
  (BSON `Date`, UTC). Discriminated shapes carry `kind` and the validator
  branches on it.
- Money as `Decimal128` or integer minor units. Never a double.

## Indexes for every query shape

- Compound index order is ESR: Equality fields first, then Sort fields, then
  Range fields. `find({ tenantId, status }).sort({ createdAt: -1 })` needs
  `{ tenantId: 1, status: 1, createdAt: -1 }`; sort direction in the index
  must match or be fully reversed.
- One index per query shape, the leftmost-prefix rule as in Postgres. Over
  10 indexes on a collection is a smell: each write updates every index.
- Partial: `partialFilterExpression: { status: 'open' }` for a hot subset;
  the query must include the same predicate. Unique + partial replaces
  sparse.
- TTL: `{ expiresAt: 1 }, { expireAfterSeconds: 0 }` on a `Date` field;
  the reaper runs every 60 seconds and deletes in the background; it cannot
  be compound.
- Text search: Atlas Search or an external engine; the legacy `text` index is
  one per collection and slow.
- Verify with `explain('executionStats')`: `COLLSCAN` in a request path is
  a finding; `totalDocsExamined / nReturned` over 10 means the wrong index;
  an in-memory `SORT` stage fails at 100 MB unless `allowDiskUse`.
- Build indexes in migration files with `createIndex` (foreground since 4.2
  is non-blocking but consumes IO; schedule off-peak above 10M documents).
  Test a removal with `hideIndex` for a week before `dropIndex`.

## Transactions

- Single-document writes are atomic; model so that one business operation
  is one document write wherever possible.
- Multi-document transactions when an invariant spans documents: keep them
  under 1,000 modified documents and under 5 seconds (the default lifetime
  limit is 60 seconds and locks held that long block writers). Retry on
  `TransientTransactionError` and `UnknownTransactionCommitResult` (use the
  driver's `withTransaction`). No network call inside.
- A transaction on every request is the sign the data is relational; see
  the store choice in `SKILL.md`.

## Read and write concerns

- Writes: `w: 'majority'` (the default since 5.0) for anything not
  re-derivable; never `w: 0`. Reads: `readConcern: 'majority'` and
  `readPreference: 'primary'` for read-your-writes; `secondaryPreferred`
  only for reporting that tolerates seconds of lag, with `maxStalenessSeconds`.
- Causal consistency sessions when a client reads after its own write
  through a secondary.

## Pagination and aggregation

- Keyset: `find({ ...filter, _id: { $lt: lastId } }).sort({ _id: -1 })
  .limit(50)` or `(sortField, _id)` pairs. `skip()` past 10,000 walks every
  skipped document.
- Pipelines: `$match` first and on indexed fields, `$project` early to cut
  width, `$lookup` only with an index on the foreign field and a bounded
  result, `$unwind` only on bounded arrays, `$limit` before `$lookup` when
  possible. Each stage has 100 MB in memory; `allowDiskUse: true` is for
  jobs, not request paths.
- `$facet` for a page plus its count in one round trip; `$merge` or `$out`
  for materialised reporting collections rebuilt on a schedule.
- `$where`, `$function`, and server-side JavaScript are disabled and a
  finding.

## Schema migration

- Versioned documents: bump `schemaVersion`, ship code that reads both
  versions and writes the new one, extend the validator with `oneOf`, then
  migrate lazily on read and in a background job in batches of 1,000 by
  `_id` range with a pause, then tighten the validator and remove the old
  read path. `updateMany({})` over a whole collection in one call is a
  finding above 100,000 documents.
- Migration files (migrate-mongo or the repo's runner) contain: validator
  `collMod`, `createIndex`/`hideIndex`/`dropIndex`, and the batch job
  invocation. Down restores the previous validator and drops added indexes;
  data written in the new shape is stated as not reversible.

## Change streams

- `watch()` on a replica set with `fullDocument: 'updateLookup'`; persist the
  resume token after every processed event; on restart resume from it. If
  the token has fallen off the oplog the consumer must re-snapshot: size the
  oplog for at least 24 hours of writes and alert on `replSetGetStatus`
  oplog window under 12 hours.
- Use for CDC into ClickHouse or an outbox; never for request-path logic.

## Security

- Authentication on (`security.authorization: enabled`), SCRAM-SHA-256, TLS
  between members and clients, bound to the private network only. One user
  per service with `readWrite` on its own database; no `root` in an
  application connection string.
- Injection: reject any input key starting with `$` or containing `.` before
  it reaches a query (a schema at the boundary does this); never pass a
  request body straight into `find()` or `$match`.
- Field-level encryption: PII that must not be readable by an operator (ids
  from government documents, health data) uses Queryable Encryption or CSFLE
  with keys in the KMS; the field list is in the migration header and the
  ADR.
