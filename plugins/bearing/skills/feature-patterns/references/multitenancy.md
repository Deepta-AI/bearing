# Pattern: multitenancy

Every row knows its tenant, every request knows its tenant, and the
check that they match lives in one place. Isolation is a property of
the data layer, not a habit of the handlers.

Markers: `tenant_id|TenantID|current_tenant|row level security|CREATE POLICY|search_path|tenant_schema|X-Tenant`
Decision keys (ADR grep): `tenant`, `multi-tenant`, `isolation`, `row level security`

## Decision questions

1. Isolation model: row level (one database, `tenant_id` on every table,
   RLS policies; recommend up to thousands of tenants), schema per tenant
   (one database, `search_path`; migrations run N times; up to hundreds),
   database per tenant (strongest isolation, highest cost; for regulated
   or very large tenants). A hybrid (row level with a few dedicated
   databases) is common; the plan says which tenants get which.
2. Tenant identity source: the JWT claim (recommend), a subdomain, a
   header? Never a body field. Subdomain and header are hints resolved
   to the claim, not trusted on their own.
3. Propagation: request context carries the tenant from the auth
   middleware into every repository call and every job payload; a job
   without a tenant is rejected.
4. Cross-tenant operations: admin views, billing, support impersonation.
   Each is an explicit, audited path with its own authorisation, never
   "skip the filter".
5. Noisy neighbour limits: per-tenant rate limits (rate_limit pattern),
   per-tenant queue concurrency, per-tenant storage quotas, statement
   timeouts. Numbers in `tenant_limits`.
6. Data lifecycle: tenant export and deletion within a stated time;
   deletion covers every store, backups noted with their retention.

## Data model (row level)

```
tenants(id, slug unique, plan, status[active|suspended|deleted], created_at)
tenant_limits(tenant_id, key, value)              -- rate, concurrency, storage_bytes, seats
every table: tenant_id not null references tenants(id), plus (tenant_id, <natural key>) uniques
indexes: tenant_id leads every composite index used by list queries
RLS: alter table t enable row level security;
     create policy tenant_isolation on t using (tenant_id = current_setting('app.tenant_id')::uuid);
     the app role has no BYPASSRLS; a migration role does
```

The connection sets `app.tenant_id` per transaction (`set local`), so a
pooled connection cannot leak the previous tenant.

## Flow

1. Auth middleware validates the token, resolves the tenant, checks
   `status = active`, puts the tenant in the context.
2. The repository layer opens a transaction, `set local app.tenant_id`,
   runs the queries. A query without a transaction is a lint finding.
3. Jobs carry `tenant_id` in the payload; the worker sets it the same way.
4. Admin paths use a separate role and write an audit row with the actor,
   the tenant and the reason.

## Failure modes

| Fault | Handling |
| --- | --- |
| missing `WHERE tenant_id` | RLS makes the query return nothing instead of everything; a test proves it |
| pooled connection reuse | `set local` inside the transaction; a test runs two tenants on one connection in sequence |
| tenant in a body field | ignored; the claim wins; a test sends a mismatched body |
| migration skips a policy | a CI check counts tables with `tenant_id` against tables with a policy; must be equal |
| suspended tenant keeps working | status checked in middleware and in the job worker |
| one tenant floods the queue | per-tenant concurrency; fairness by round robin over tenant queues |
| backup restore mixes tenants (database per tenant) | restore drills per tenant (`resilience-testing`) |
| id enumeration across tenants | uuids; and the filter, not the id shape, is the boundary |

## Tests to write

- tenant A cannot read, update or delete tenant B's row through every endpoint (a table-driven test over the routes)
- a query with no tenant set returns zero rows (RLS), not all rows
- two tenants on one pooled connection in sequence see only their own rows
- a job payload without `tenant_id` is rejected before it runs
- a suspended tenant gets 403 on every authenticated route
- the policy count equals the tenant table count (schema test)
- tenant deletion removes rows from every store and the export contains every table
- per-tenant rate limit and concurrency hold under a two-tenant load test

## Per-stack pointers

- Go: tenant in `context.Context` via a typed key; repository helper `withTenantTx(ctx, fn)` that sets `app.tenant_id`; `pgx` pool.
- Python: `contextvars` for the tenant; SQLAlchemy `with_loader_criteria` as a second belt on top of RLS; `set local` in a session event.
- React and mobile clients: the tenant comes from the token; a tenant switcher re-authenticates rather than changing a header.
- Schema per tenant: migrations loop over schemas in one transaction per schema; `search_path` set per request; keep a `public` schema for shared tables.
- Database per tenant: a catalog table of connection strings from the secret manager; pool per tenant with an idle eviction.
