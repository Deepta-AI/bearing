# ADR 0004: Money is integer paise everywhere

Status: Accepted (2026-03-12)

## Context

Two reconciliation incidents in February came from rupee amounts held as
floats and rounded differently by the web app and the ledger import.

## Decision

Every amount is an integer number of paise: in storage, in function
arguments, in API responses and in every file we export (CSV and JSON).
Converting to rupees for display happens only in the web app, at render
time. A column that carries money in an export is named with the
`_paise` suffix.

## Consequences

Accountants who want rupees in a spreadsheet divide by 100 there. A
change to this rule needs a new ADR that supersedes this one.
