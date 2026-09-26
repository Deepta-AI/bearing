# Technical debt register

Review cadence: monthly, first working week   Owner: billing lead
Last seed: 2026-06-03
Last review: 2026-06-03   Total interest: 9.5 h/week

Interest is what the item costs per week (hours, `est.` when estimated).
Principal is the effort to pay it off (hours). Trigger is when it must be
paid. Ids are never reused; paid rows move to the Paid table with a date.

## Open

| Id | Description (file:line) | Class | Interest h/wk | Principal h | Trigger | Owner | Added |
| --- | --- | --- | --- | --- | --- | --- | --- |
| DEBT-001 | TODO N+1 query in list_invoices, customer page 3 s (src/invoicing/repo.py:9) | marker | 3 | 4 | before the customer portal launch | @finance-eng/billing | 2026-06-03 |
| DEBT-002 | noqa E501 long header line in the PDF render (src/invoicing/pdf.py:5) | suppression | 0 | 2 | none | @finance-eng/billing | 2026-06-03 |
| DEBT-003 | skipped test test_multi_line_matches_invoice_rounding (tests/test_credit_notes.py:12) | skipped test | est. 2 | est. 10 | when credit_notes.py is next changed | @finance-eng/billing | 2026-06-03 |
| DEBT-004 | HACK GST hard-coded at 18% (src/invoicing/tax.py:7) | marker | est. 1 | est. 3 | when tax.py is next changed | @finance-eng/billing | 2026-06-03 |
| DEBT-005 | quarantined test test_rejects_tampered_body (tests/test_webhooks.py:17) | quarantine | est. 1.5 | est. 3 | quarantine deadline 2026-08-31 | @finance-eng/billing | 2026-06-03 |
| DEBT-006 | TODO retry the gateway on 503, charges fail on blips (src/invoicing/gateway.py:7) | marker | est. 2 | est. 2 | before the October billing run | @finance-eng/billing | 2026-06-03 |
| DEBT-007 | type: ignore arg-type in to_inr (src/invoicing/fx.py:7) | suppression | ? | est. 6 | when fx.py is next changed | @finance-eng/billing | 2026-06-03 |
| DEBT-008 | FIXME month export built in memory, March export OOM-killed (src/invoicing/export.py:8) | marker | est. 4 | est. 16 | before the next month over 150k rows | @finance-eng/reporting | 2026-06-03 |

## Needs an estimate

| Id | Description | Missing |
| --- | --- | --- |
| DEBT-007 | type: ignore arg-type in to_inr | interest: ask finance how often foreign-currency invoices are issued |

## Paid

| Id | Description | Paid on | Task | Interest saved h/wk |
| --- | --- | --- | --- | --- |

## Review log

| Date | Open | Paid this month | Interest h/wk | Top item | Decision |
| --- | --- | --- | --- | --- | --- |
| 2026-06-03 | 8 | 0 | 9.5 | DEBT-006 | seeded; pay DEBT-006 when someone has a free afternoon |
