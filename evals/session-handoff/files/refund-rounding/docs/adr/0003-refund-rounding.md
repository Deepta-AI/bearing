# 0003 How refunds round

Status: Proposed (2026-09-21), awaiting sign-off from the finance operations lead

## Context

The ledger team reports that refunds of multi-line orders are sometimes one
paisa higher than the ledger's figure. Today every line is rounded half-up on
its own and the rounded lines are summed.

## Options

1. Keep half-up, round every line (today).
2. Half-to-even on every line.
3. Round the order total once, half-to-even.

## Open question

Which of 2 or 3 matches the ledger? Finance operations owns the answer; it
has been asked and has not replied. Nothing changes in `refunds/calc.py`
until this ADR is Accepted.
