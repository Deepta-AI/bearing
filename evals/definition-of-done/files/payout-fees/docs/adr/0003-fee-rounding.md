# ADR 0003: Platform fees round half up to the paisa

Status: Accepted (2026-05-19)

## Context

The fee on an order line is `amount * rate_bps / 10000` paise, which is
rarely a whole number. Sellers reconcile our statements against their own
spreadsheets, which round half up.

## Decision

The platform fee on each line is rounded half up to the nearest paisa:
19.5 paise becomes 20, 19.4 paise becomes 19. The fee on a payout is the sum
of its line fees, never a fee computed on the payout total.

## Consequences

Line fees and statement totals match what sellers compute. Integer
arithmetic only: `(amount * rate_bps + 5000) // 10000`.
