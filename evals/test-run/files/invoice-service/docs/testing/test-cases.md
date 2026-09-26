# Test cases

| TC | Story | Title | Suite | Priority |
| --- | --- | --- | --- | --- |
| TC-0010 | US-01-001 | A new invoice starts as a draft | unit | P2 |
| TC-0011 | US-01-001 | Invoice total is the sum of its lines | unit | P1 |
| TC-0012 | US-01-004 | Late fee never exceeds Rs 500 per invoice | unit | P1 |
| TC-0013 | US-01-004 | No late fee within the 7 day grace period | unit | P1 |
| TC-0015 | US-01-006 | A credit note reduces the invoice total | unit | P1 |
| TC-0020 | US-02-001 | Intra-state GST splits into CGST and SGST | unit | P1 |
| TC-0021 | US-02-001 | CGST and SGST add up to the full GST | unit | P1 |
| TC-0022 | US-02-002 | Inter-state GST is charged as IGST | unit | P1 |
| TC-0030 | US-03-001 | An invoice saved to Postgres loads unchanged | integration | P1 |
| TC-0031 | US-03-002 | Overdue invoices are listed by due date | integration | P2 |
| TC-0040 | US-04-001 | Billing on the 31st falls back to the last day of short months | unit | P1 |
