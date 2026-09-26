# 3. Money as integer paise

Date: 2026-06-10

## Status

Accepted

## Context

A pilot build stored prices as floating point rupees and a 3 line order
totalled 1799.9999999 in the approval email.

## Decision

We will store and transmit every amount as an integer number of paise
with an ISO 4217 currency code beside it. Only INR is supported today.

## Consequences

Clients format for display. No field anywhere carries rupees as a
decimal.
