# Schema notes

Last updated 2025-11-20. Latest migration: 0009.

## invoices

| column      | type        | notes                                     |
|-------------|-------------|-------------------------------------------|
| id          | bigint      | identity                                  |
| tenant_id   | bigint      | FK tenants                                |
| customer_id | bigint      | FK customers                              |
| number      | bigint      | per tenant, see ADR 0002                  |
| status      | text        | draft, sent, paid, void                   |
| total_minor | bigint      | minor units                               |
| currency    | char(3)     |                                           |
| issued_at   | timestamptz | set when the invoice leaves draft         |
| created_at  | timestamptz |                                           |
| deleted_at  | timestamptz | soft delete, drafts only                  |
| voided_at   | timestamptz |                                           |

Indexes: `idx_invoices_tenant`, `idx_invoices_customer`, `idx_invoices_status`,
`idx_invoices_tenant_created`.

The tenant invoice list (GET /tenants/{id}/invoices) is served by
`idx_invoices_tenant_created`, newest first.
