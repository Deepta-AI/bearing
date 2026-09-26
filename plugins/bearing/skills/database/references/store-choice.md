# Picking the store

PostgreSQL is the default. Any other choice gets an ADR in the same MR.

**PostgreSQL** holds anything a user creates, edits, pays for or is
shown as current truth: accounts, orders, invoices, permissions, state
machines, anything with an invariant across rows. Signs it was the wrong
choice: an append-only table past 100M rows queried only by time range
and aggregate; a `count(*)` over months of rows inside a request; a
`jsonb` column holding the whole entity with every query using `->>`; a
table with one insert per event and no update ever.

**ClickHouse** holds events and analytics: immutable facts at thousands
of rows per second (product events, audit trails, metrics, logs, CDC
copies of Postgres tables for reporting), read by scans and aggregates
over a time range with a few equality filters, latency in hundreds of
milliseconds. Signs it was the wrong choice: the app runs `ALTER TABLE
... UPDATE` or `DELETE` by id; point lookups by key expected in
single-digit milliseconds; one-row inserts from request handlers; a
foreign key needed for correctness; anything that needs a transaction.

**MongoDB** holds document-shaped data behind a validator: records read
and written as a whole whose shape varies by a discriminator and nests
naturally (a CMS page, a form definition and its submissions, a
catalogue item with variants, a per-tenant configuration). Every
collection has a `$jsonSchema` validator or it does not exist. Signs it
was the wrong choice: `$lookup` in most queries; multi-document
transactions on a normal path; an array that grows with usage (messages,
events, history); money or stock counts with invariants across
documents; reports that need joins.

The choice is one `tech-decision` key (`database`, `analytics store`); the
reasons above are the recommendation's reasons, not a substitute for the
user's decision.
