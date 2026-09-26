# Duplicate invoice numbers (finance, 2026-09-18)

An auditor found two invoices with the same number for one tenant. Finance
ran this on a replica on 2026-09-17:

```sql
SELECT tenant_id, number, count(*) AS n,
       count(*) FILTER (WHERE deleted_at IS NOT NULL) AS deleted
FROM invoices
GROUP BY tenant_id, number
HAVING count(*) > 1;
```

Result: 212 rows (tenant and number pairs) across 9 tenants, every one with
n = 2. In 171 of them one of the two invoices is a deleted draft; in the other
41 both invoices are live and were created within the same second.

Finance is agreeing with the auditors how to correct the 41 live pairs
(credit notes or reissue). Until that is signed off, no issued invoice may be
renumbered, edited or deleted, by anyone, for any reason.
