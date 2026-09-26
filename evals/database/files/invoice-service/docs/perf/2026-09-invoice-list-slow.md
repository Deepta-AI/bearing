# Invoice list slow for large tenants (support ticket, 2026-09-22)

Tenant 42 reports the invoice list page takes 1 to 4 seconds. From the access
log over the last 7 days, GET /tenants/{id}/invoices:

- 94% of calls have no `status` filter; 5% filter `status=sent`, 1% others.
- 81% of calls are page 1; 97% are page 5 or earlier; a few integrations walk
  every page (tenant 42's nightly sync reaches page 24,000).
- p95: 180 ms for tenants under 10k invoices, 1.9 s for tenant 42 page 1,
  4.1 s for tenant 42 page 400.

Plan for page 1, tenant 42, no status filter, captured on a replica:

```
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, number, status, total_minor, currency, issued_at FROM invoices
WHERE tenant_id = 42 AND deleted_at IS NULL AND (NULL::text IS NULL OR status = NULL)
ORDER BY issued_at DESC, id DESC LIMIT 50 OFFSET 0;

Limit  (cost=318911.20..318911.33 rows=50 width=48) (actual time=1874.311..1874.322 rows=50 loops=1)
  Buffers: shared hit=40211 read=118904
  ->  Sort  (cost=318911.20..321938.61 rows=1210964 width=48) (actual time=1874.309..1874.315 rows=50 loops=1)
        Sort Key: issued_at DESC, id DESC
        Sort Method: top-N heapsort  Memory: 33kB
        ->  Bitmap Heap Scan on invoices  (cost=22641.07..278684.44 rows=1210964 width=48) (actual time=96.515..1602.742 rows=1210544 loops=1)
              Recheck Cond: (tenant_id = 42)
              Filter: (deleted_at IS NULL)
              Rows Removed by Filter: 197122
              ->  Bitmap Index Scan on idx_invoices_tenant  (cost=0.00..22338.33 rows=1407551 width=0) (actual time=88.004..88.004 rows=1407666 loops=1)
                    Index Cond: (tenant_id = 42)
Planning Time: 0.211 ms
Execution Time: 1874.402 ms
```
