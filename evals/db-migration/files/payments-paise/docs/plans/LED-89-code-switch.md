# LED-89: switch the code to integer paise (the MR after LED-88)

Status: planned, not started.

- `record_payment` and `record_refund` write `amount_paise` only; new rows
  leave `amount` NULL.
- `correct_amount` updates `amount_paise` only.
- `total_for_customer` sums `amount_paise`.
- LED-90, one release later, drops `payments.amount` (ADR 0002).
