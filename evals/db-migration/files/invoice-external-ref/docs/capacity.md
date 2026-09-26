# Capacity (updated 1 September 2026)

| table          | rows       | growth per month | notes                                  |
|----------------|------------|------------------|----------------------------------------|
| tenants        | 4,100      | 150              |                                        |
| customers      | 2.9 M      | 90 k             |                                        |
| invoices       | 38 M       | 1.2 M            | hot: every checkout and webhook writes |
| invoice_lines  | 141 M      | 4.5 M            |                                        |
| payment_events | 52 M       | 1.6 M            | append only                            |

Peak write rate on invoices is about 220 per second (month-end runs).
Autovacuum and the nightly report hold long read transactions on invoices
for up to 25 minutes between 01:00 and 02:00 IST.
