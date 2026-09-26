# Data model: <scope>

**Store:** PostgreSQL · **Tables:** 2 · **Columns:** 15 · **Indexes:** 3 · **Personal-data columns:** 2

<!-- Template guidance: every section below carries a comment saying what goes
     there (What), what a strong entry has (Good) and a one-line example
     (Example). Delete each comment when you fill its section. The data model
     is where stories become columns: who owns each entity, how it is born
     and dies, which store holds it, and the reason behind every column,
     index and constraint. Engineers writing migrations and LLDs read it; a
     reviewer reads it to decide whether the schema can be built.
     The headline line above counts the Postgres tables, their columns, the
     named indexes in schema.sql and the columns marked personal data; the
     gate (scripts/model_check.py) fails when the counts disagree with
     schema.sql and data-dictionary.csv. The example rows (customers,
     invoices) match the example schema.sql and data-dictionary.csv
     templates; replace all three together.
     Follow database's references; record only the deviations, never
     copy the rules in. Delete the sections for stores this scope does not
     use, and renumber the remaining sections so they run without gaps. -->

One paragraph: what this database holds, which surfaces read and write it,
and why the stores below are enough.

- Task: TASK-ID
- Serves: US-nn-nnn, REQ-nnn
- ADRs: ADR-nnnn (store choice) | ADR needed
- Stores: postgres | mongodb | clickhouse
- Companion files: `docs/design/schema.sql`, `docs/design/data-dictionary.csv`, `docs/design/erd.md`
- Author (git config user.name, never a guessed name), date, status (Draft | Reviewed | Approved), version v1

## 1. Why these stores

<!-- What: one subsection per store this design uses: what it holds, why,
     and a Considered | Why not table for the stores rejected.
     Good: the reason is tied to the stories (consistency, access pattern,
     volume), and each rejected store names the requirement it fails; a
     store no ADR chose says "ADR needed".
     Example: the PostgreSQL subsection below. -->

### PostgreSQL

<!-- What: Holds (the entities in this store), the reason in two or three
     sentences, then the rejected alternatives with the reason each fails.
     Good: the reason names a story, a volume or a consistency need, never
     "it is the default".
     Example: "ClickHouse: invoices are edited records with status changes,
     not append-only events." -->

**Holds:** customers and invoices, and the aggregate queries that read them.

Every acceptance criterion is relational and consistency-critical: an
invoice must reference a live customer, and the tenant boundary is a
foreign-key and index concern. Thousands of invoices per tenant a year is an
ordinary index scan.

| Considered | Why not |
| --- | --- |
| MongoDB | The invoice and customer shapes are fixed and cross-referenced; the stories need foreign keys and constraints, not documents read whole. |
| ClickHouse | Invoices are edited records with status changes, not append-only events; the reports aggregate a few thousand rows on demand. |

## 2. Entities: ownership and lifecycle

<!-- What: one row per entity: owner (service or module), lifecycle
     (created by, changed by, ended by: delete, archive or expiry), the
     story ids it serves, PII yes or no, retention.
     Good: every entity traces to a US-nn-nnn id; an entity no story reads
     or writes is cut and named on the "Not modelled" line.
     Example: the invoice row below, and "Not modelled: audit_note, because
     no story reads or writes it." -->

| Entity | Owner | Created by | Changed by | Ended by | Stories | PII | Retention |
| --- | --- | --- | --- | --- | --- | --- | --- |
| customer | billing module | US-01-001 | US-01-001 | delete when the tenant closes | US-01-001, US-01-002 | yes | tenant life + 30 d |
| invoice | billing module | US-01-002 | US-01-002, US-01-003 | archive after 7 y | US-01-002, US-01-003 | no | 7 years |

Not modelled: <entity>, because <no story reads or writes it>.

## 3. Relationships

<!-- What: one row per foreign key: from, to, cardinality, the FK column,
     its ON DELETE and why. The mermaid diagram with a sentence per
     relationship is docs/design/erd.md.
     Good: every ON DELETE is explicit and its reason says what must not
     happen (an orphan, a silent cascade of records a story keeps).
     Example: the invoices row below. -->

| From | To | Cardinality | FK column | On delete | Why |
| --- | --- | --- | --- | --- | --- |
| customers | invoices | one-to-many | invoices.customer_id | RESTRICT | A customer with invoices cannot be deleted; US-01-002 keeps every invoice. |

## 4. PostgreSQL tables

<!-- What: one subsection per table, in the order schema.sql creates them.
     The DDL itself lives in docs/design/schema.sql; this section gives the
     reason for each piece of it, following
     database/references/postgres.md.
     Good: timestamptz audit columns, NOT NULL by default, every FK with an
     explicit ON DELETE and an index on the referencing column, tenant_id
     first in composite keys; hot tables marked.
     Example: the customers and invoices subsections below. -->

### `customers`: Customers (hot: no)

<!-- What: the purpose in one sentence, "Serves US-...", the expected
     volume with its order of magnitude and what drives it, then the column
     table, the named indexes and the named CHECK constraints.
     Good: every column's Why quotes the acceptance criterion or names the
     rule it exists for; every index says the query it serves; every CHECK
     says what bad row it refuses.
     Example: the rows below. -->

A party a tenant bills; the invoice is addressed to it.

Serves US-01-001, US-01-002. Expected volume: thousands of rows per tenant
after a year (10^4 in total), driven by one row per billed party.

| Column | Type | Null | Key | Default | Description | Why |
| --- | --- | --- | --- | --- | --- | --- |
| `id` | `uuid` | No | PK | `gen_random_uuid()` | Surrogate key; the id every invoice references. | US-01-002 AC1: an invoice names its customer. |
| `tenant_id` | `uuid` | No | | | The tenant that owns this customer. | Rule: tenant isolation (US-01-001 AC3). |
| `display_name` | `text` | No | | | Name printed on the invoice. **(personal data)** | US-01-001 AC1: the form requires a name. |
| `email` | `text` | No | UK | | Address the invoice is sent to. **(personal data)** | US-01-002 AC4: sending emails the customer. |
| `created_at` | `timestamptz` | No | | `now()` | When the customer was added. | Rule: audit columns. |
| `updated_at` | `timestamptz` | No | | `now()` | Last change to this row. | Rule: audit columns. |

**Indexes**

- `uq_customers_tenant_email`: unique on (tenant_id, lower(email)). Serves
  the duplicate check on import and on the add-customer form (US-01-001 AC2).

**Constraints**

- `chk_customers_display_name_not_blank`: `btrim(display_name) <> ''`. A
  blank name prints an unaddressed invoice.
- `chk_customers_email_shape`: `email ~ '^[^@[:space:]]+@[^@[:space:]]+$'`.
  Refuses a value the send step cannot deliver to.

### `invoices`: Invoices (hot: yes)

<!-- What: the same shape as the table above, for the next table.
     Good: a hot table says what makes it hot (reads per second or rows
     written per day) so a migration on it plans its locks.
     Example: "hot: yes, the invoice list is the busiest read." -->

A bill sent to one customer, with its lifecycle status.

Serves US-01-002, US-01-003. Expected volume: tens of thousands of rows per
year (10^4 to 10^5), driven by invoices issued per tenant per month. Hot:
the invoice list is the busiest read.

| Column | Type | Null | Key | Default | Description | Why |
| --- | --- | --- | --- | --- | --- | --- |
| `id` | `uuid` | No | PK | `gen_random_uuid()` | Surrogate key; the id in the invoice URL. | US-01-003 AC1: the page is addressed by id. |
| `tenant_id` | `uuid` | No | | | The tenant that issued the invoice. | Rule: tenant_id first in composite keys. |
| `customer_id` | `uuid` | No | FK customers.id | | The customer billed. | US-01-002 AC1: one customer per invoice. |
| `status` | `invoice_status` | No | | `'draft'` | Lifecycle status. | US-01-003 AC3: the list filters by status. |
| `amount_minor` | `bigint` | No | | | Total in minor units. | Rule: money is an integer in minor units. |
| `currency` | `char(3)` | No | | | ISO 4217 code. | US-01-002 AC2: the total shows its currency. |
| `due_on` | `date` | No | | | Date payment is due. | US-01-003 AC4: overdue invoices are flagged. |
| `created_at` | `timestamptz` | No | | `now()` | When the invoice was drafted. | US-01-003 AC2: newest first. |
| `updated_at` | `timestamptz` | No | | `now()` | Last change to this row. | Rule: audit columns. |

**Indexes**

- `idx_invoices_customer_id`: on (customer_id). A customer's invoices, and
  the FK-index rule so a customer delete check does not scan the table.
- `idx_invoices_tenant_status_created`: on (tenant_id, status, created_at
  DESC). The invoice list: one tenant, filtered by status, newest first
  (US-01-003 AC2, AC3).

**Constraints**

- `chk_invoices_amount_positive`: `amount_minor > 0`. A zero or negative
  invoice is a credit note, which no story models.
- `chk_invoices_currency_iso`: `currency ~ '^[A-Z]{3}$'`. A lowercase or
  partial code breaks the formatter and the totals by currency.

## 5. MongoDB

<!-- What: one subsection per collection, following
     database/references/mongodb.md. Collections are documented here
     only; schema.sql and the data dictionary cover Postgres.
     Good: every collection has a $jsonSchema validator, an embed or
     reference decision with its bound, and an index per query shape.
     Example: "### `visit_notes`: embedded in visits, at most 50 notes of
     2 KB each." -->

### `<collection>`

<!-- What: the purpose, Serves line and expected volume, the embed or
     reference decision with its bound, the validator sketch and one index
     row per query shape.
     Good: the validator has required, bsonType, maxItems, maxLength,
     additionalProperties: false and schemaVersion; an unbounded embedded
     array is a finding.
     Example index row: "| visits_clinic_date | { clinicId: 1, visitedAt:
     -1 } | a clinic's visits, newest first |" -->

- Embed or reference: <decision>, bound: <n items, n KB>.
- Validator sketch:

```json
{ "$jsonSchema": { "bsonType": "object", "required": ["_id", "schemaVersion", "createdAt"],
  "additionalProperties": false, "properties": { "schemaVersion": { "bsonType": "int" } } } }
```

| Index | Keys | Serves (query shape) |
| --- | --- | --- |

## 6. ClickHouse

<!-- What: one subsection per table, following
     database/references/clickhouse.md.
     Good: engine, ORDER BY, partition key, TTL and materialised views are
     each written down with the reason for the choice.
     Example: "### `booking_events`: MergeTree, monthly partitions, 13
     month TTL." -->

### `<table>`

<!-- What: the engine and why, the ORDER BY with its rationale, the
     partition key, the TTL and the materialised views with their TO
     targets.
     Good: ORDER BY has three to five columns, equality filters first and
     lowest cardinality first; ReplacingMergeTree names its version column.
     Example: "ORDER BY (tenant_id, event_type, clinic_id, ts): every
     dashboard filters tenant and event type by equality." -->

- Engine: MergeTree | ReplacingMergeTree(<version>) and why.
- ORDER BY (<a>, <b>, <ts>): <rationale: equality filters first, lowest cardinality first>.
- PARTITION BY: <expr>. TTL: <expr>. Materialised views: <mv> TO <target>.

## 7. Enumerations

<!-- What: one row per enum type in schema.sql (or check-constrained value
     set): its name, its values, and why the set is closed.
     Good: the Why names the story or decision that fixes the set, and says
     what a new value would cost (a migration, an ADR).
     Example: the invoice_status row below. -->

| Name | Values | Why |
| --- | --- | --- |
| `invoice_status` | `draft`, `sent`, `paid`, `void` | US-01-003 AC3 filters by these four; a new status is a migration and a UI change. |

## 8. Retention and personal data

<!-- What: one row per table or collection holding data with a lifetime:
     the rule, the mechanism that enforces it and its Basis (stated, with
     the story or policy, or assumption). Then the list of personal-data
     columns.
     Good: the mechanism is real (batched hard delete, TTL, partition
     drop); a rule with no mechanism is written UNDEFINED, never left
     blank. An assumption is a decision a person must confirm before the
     first release, and the section says so.
     Example: the customers row below, whose mechanism is UNDEFINED. -->

Anything on Basis **assumption** is not a decision this document is entitled
to make. Confirm it before the first release.

| Table | Rule | Mechanism | Basis |
| --- | --- | --- | --- |
| `invoices` | Kept 7 years after issue as a statutory record, then archived. | yearly partition export and drop | stated (US-01-003 AC6) |
| `customers` | Deleted 30 days after the tenant closes. | UNDEFINED | assumption |

Personal-data columns (2): `customers.display_name` (name),
`customers.email` (contact).

## 9. Migration plan

<!-- What: the migrations in order, each a db-migration name with its
     expand, migrate or contract phase, whether it touches a hot table, and
     its lock risk and batch note. For a new database, schema.sql is
     migration 1.
     Good: a change to a hot table says how it avoids a long lock and the
     batch size of any backfill.
     Example: "| 2 | backfill_invoices_currency | migrate | yes | batches
     of 5,000 rows by id, no table lock |" -->

| # | db-migration name | Phase (expand \| migrate \| contract) | Hot table | Lock risk and batch note |
| --- | --- | --- | --- | --- |
| 1 | initial_schema (schema.sql) | expand | no | empty database, none |

## 10. Rules and deviations

<!-- What: the count of reference rules checked, then one line per
     deviation with the rule, the reason and a revisit date.
     Good: every applicable rule of each store's reference is either
     followed or has a deviation line; both are counted. Half a rule is a
     deviation (soft delete without its partial unique index and batched
     hard delete).
     Example: "deviation: tenant_id first in composite keys, the reports
     table is single tenant, revisit 2027-01-01." -->

Rules checked: N against `database/references/<store>.md`. Deviations: K.

- deviation: <rule>, <why>, revisit <date>

## 11. What the review found

<!-- What: the findings of an independent pass (the critic agent) over
     the finished schema against the acceptance criteria, each graded
     BLOCKER, MAJOR, MINOR or NIT, most severe first, with the table, the
     failure it causes and the fix. Start with the counts line.
     Good: a finding names the row or query that breaks and the criterion
     it breaks; a fixed finding says "fixed in this version"; an open
     BLOCKER stops the output contract from reading ready.
     Example: the MAJOR finding below. -->

Findings: BLOCKER 0, MAJOR 1, MINOR 0, NIT 0 (open 1).

### MAJOR: no idempotency key, so a retried create makes two invoices (`invoices`)

<!-- What: one subsection per finding: what is wrong, the failure it
     causes, and a Fix line; Status fixed or open.
     Good: the failure is concrete (a row, a request, a criterion) and the
     fix is a change someone can make.
     Example: the paragraph below. -->

A client that retries after a timeout inserts a second draft, and US-01-002
AC5 says a retry creates exactly one invoice.

**Fix:** add `idempotency_key uuid` with a unique index on (tenant_id,
idempotency_key). Status: open.

## 12. Open concerns

<!-- What: each concern the design could not settle, tagged [conflict],
     [gap], [ambiguity], [risk] or [scope], with the table it touches, the
     consequence, an owner and date, and "Blocks development: yes | no".
     Good: a conflict quotes both sides; an ambiguity says which reading
     the design took; a concern that blocks development is counted in the
     output contract.
     Example: the gap below. -->

- **[gap]** No story says whether a voided invoice keeps its number or
  frees it. Modelled as kept. (`invoices`) Owner: product lead, by
  2026-10-10. Blocks development: no.

## 13. Applying this

<!-- What: how schema.sql is used and what the gate printed.
     Good: the gate's counts line verbatim, and whether schema.sql was
     applied to an empty Postgres (or "not run" with the reason).
     Example: "data-model: 2 tables, 15 columns, 3 indexes, 4 checks, 1
     enums, 2 personal-data columns, 0 problems". -->

`schema.sql` runs top to bottom in one transaction against an empty database:
enum types first, then tables in foreign-key order. Use it as the first
migration; every change after the first release is its own migration, never
an edit to this file.

- Gate: `data-model: <counts line>`
- Applied to an empty Postgres: yes (postgres:16) | not run (<reason>)
