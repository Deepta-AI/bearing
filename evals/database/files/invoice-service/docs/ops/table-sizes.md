# Table sizes, production (2026-09-01)

| table         | rows    | total size | notes                              |
|---------------|---------|------------|------------------------------------|
| invoices      | 38.4M   | 11 GB      | 14% soft-deleted (deleted_at set)  |
| invoice_lines | 161M    | 29 GB      |                                    |
| payments      | 22.9M   | 3.1 GB     |                                    |
| customers     | 2.1M    | 410 MB     |                                    |
| tenants       | 3,412   | 1 MB       |                                    |

Invoice creation peaks at about 1,900 a minute (month end, 09:00 to 11:00
UTC). The largest tenant, tenant 42, holds 1.21M live invoices, of which
about 6% are drafts.
