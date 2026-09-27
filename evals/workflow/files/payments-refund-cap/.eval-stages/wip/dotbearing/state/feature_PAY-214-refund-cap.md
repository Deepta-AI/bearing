# Session state: feature/PAY-214-refund-cap

Updated: 2026-09-19 18:40

## Where I stopped
- Put the refund_audit table in migrations/0002_refunds.sql next to refunds.
- audit.go is a stub; the handler calls it but nothing is written yet.
- The 422 path works when tried by hand with curl.

## Next
- write TestRefundOverCap
