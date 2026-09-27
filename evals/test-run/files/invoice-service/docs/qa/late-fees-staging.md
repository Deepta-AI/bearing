# Late fees on staging (QA, 24 Sep 2026)

Checked the late fee on two overdue invoices on staging after the September
deploy. Both look wrong to us.

| Invoice | Outstanding | Days late | Late fee charged | What we expected |
| --- | --- | --- | --- | --- |
| INV-2207 | Rs 20,000 | 75 | Rs 750 | Rs 500 (the cap) |
| INV-2291 | Rs 12,000 | 37 | Rs 480 | Rs 240 |

Rule we tested against: 2% of the outstanding amount per full month overdue,
after the 7 day grace period, never more than Rs 500 per invoice.
