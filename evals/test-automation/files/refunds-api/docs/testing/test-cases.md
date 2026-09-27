# Test cases

Amounts in rupees; the API takes paise.

| TC | Story | AC | Title | Preconditions | Steps | Test data | Expected | Type | Priority | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| TC-0090 | US-07-001 | AC-US-07-001-1 | orders listed newest first | 25 orders for one customer | 1. GET the first page | customer cus_1 | 20 orders, newest first | integration | P2 | planned |
| TC-0101 | US-07-002 | AC-US-07-002-1 | full refund of a captured order | order ord_1 captured, 1000.00 | 1. refund 1000.00 | 1000.00 | 201, refund recorded for 1000.00 | integration | P1 | automated |
| TC-0102 | US-07-002 | AC-US-07-002-1 | refund of an uncaptured order | order ord_2 authorized only | 1. refund 100.00 | 100.00 | 409 order_not_captured | integration | P1 | automated |
| TC-0103 | US-07-002 | AC-US-07-002-1 | partial refund leaves the rest refundable | order ord_1 captured, 1000.00 | 1. refund 250.00 2. list the order's refunds | 250.00 | 201; refunded 250.00, refundable 750.00 | integration | P1 | planned |
| TC-0104 | US-07-002 | AC-US-07-002-2 | refund larger than what is left | order ord_1 captured, 1000.00, 250.00 already refunded | 1. refund 800.00 | 800.00 | 422 exceeds_refundable; refundable still 750.00 | integration | P1 | planned |
| TC-0105 | US-07-002 | AC-US-07-002-3 | zero amount rejected | order ord_1 captured | 1. refund 0.00 | 0.00 | 422 invalid_amount | integration | P2 | planned |
| TC-0106 | US-07-002 | AC-US-07-002-4 | refund after the 30 day window | order ord_3 captured 2026-08-01 10:00 UTC | 1. refund 100.00 on 2026-09-01 10:00 UTC | 100.00 | 422 refund_window_closed | integration | P1 | planned |
| TC-0107 | US-07-002 | AC-US-07-002-5 | refund receipt download | a refund exists on ord_1 | 1. GET /refunds/{id}/receipt | refund from TC-0101 | 200, application/pdf | integration | P2 | planned |
| TC-0108 | US-07-002 | AC-US-07-002-6 | money reaches the bank | refund issued on a real card | 1. check the customer's bank statement on day 7 | test card in the sandbox bank | credit for the refund amount | e2e | P3 | planned |
| TC-0109 | US-07-002 | AC-US-07-002-7 | refund.created published | order ord_1 captured, 1000.00 | 1. refund 300.00 | 300.00 | one refund.created event with ord_1, the refund id and 300.00 | integration | P1 | planned |
| TC-0110 | US-07-002 | AC-US-07-002-4 | refund on the last evening of the window | order ord_4 captured 2026-08-01 10:00 UTC, 1000.00 | 1. refund 100.00 on 2026-08-31 15:00 IST | 100.00 | 201; refund recorded for 100.00 | integration | P1 | planned |
| TC-0111 | US-07-002 | AC-US-07-002-2 | two refunds racing for what is left | order ord_5 captured, 1000.00 | 1. send two refunds of 600.00 at the same moment | 600.00 twice | one 201 and one 422 exceeds_refundable; refunded 600.00, refundable 400.00 | integration | P1 | planned |
