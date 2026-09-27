# Test cases: checkout

| TC | Story | Title | Expected result |
| --- | --- | --- | --- |
| TC-0101 | US-12-001 | Primary action on a filled cart | A cart with items shows the primary checkout button, enabled. |
| TC-0102 | US-12-001 | No checkout from an empty cart | With an empty cart the primary checkout button is shown disabled, so no order can be placed. |
| TC-0103 | US-12-001 | Total shown | The page shows the order total: two items at 600 rupees each total 1,200.00 rupees with free shipping. |
| TC-0104 | US-12-002 | Free shipping at the threshold | A cart of exactly 500 rupees ships free (shipping 0.00); the threshold is inclusive. |
| TC-0105 | US-12-002 | Shipping fee below the threshold | A cart of 499 rupees pays the 40 rupee shipping fee. |
| TC-0106 | US-12-003 | Coupon applies | A valid 10 percent coupon on a 1,200 rupee cart shows the coupon and a total of 1,080.00 rupees. |
| TC-0107 | US-12-001 | Primary action label | The primary checkout button reads "Pay now". |
