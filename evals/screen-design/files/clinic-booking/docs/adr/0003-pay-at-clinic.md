# ADR-0003: Fees are paid at the clinic; the app takes no payments

Status: Accepted, 20 Aug 2026

## Context

Taking card payments in the app puts the app and its backend in scope for
PCI DSS and needs a payment gateway contract, refunds for cancellations and
reconciliation with the clinics' tills. None of that exists.

## Decision

The app never collects card or other payment details. The confirmation
screen states the fee and that it is paid at the clinic.

## Revisit when

Finance has a gateway contract and a refund policy for cancelled visits.
