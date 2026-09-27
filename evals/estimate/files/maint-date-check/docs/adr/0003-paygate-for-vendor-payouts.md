# ADR-0003: Vendor payouts through PayGate

Status: Accepted, 2026-08-21

## Context
Landlords want vendors paid automatically when a job is closed. We will
not hold money ourselves.

## Decision
Payouts go through PayGate's payout API. We store only PayGate's payout
reference and status, never bank details.

## Consequences
- PayGate issues sandbox and live credentials only after our business KYC
  is approved. PayGate quotes 15 working days from a complete submission.
- Every vendor must complete PayGate's beneficiary verification before
  their first payout; an unverified vendor cannot be paid.
- Payouts are asynchronous: PayGate confirms by webhook, usually within
  minutes, sometimes the next working day.
