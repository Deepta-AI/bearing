# 0002. Store money as integer minor units

Status: Accepted

## Context

Rounding errors on float amounts caused a reconciliation incident in a
previous product.

## Decision

We will store every amount as `bigint` minor units (paise) in a column
named `<name>_minor`, with a `currency char(3)` column beside it.

## Consequences

Formatting happens in the UI; the database never holds a decimal amount.
