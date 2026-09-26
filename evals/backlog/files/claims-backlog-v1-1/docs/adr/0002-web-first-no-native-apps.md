# ADR-0002: Responsive web only, no native apps in 2026

Status: Accepted, 2026-07-02

## Context
We have two engineers and no mobile developer. Most claims are filed from a
phone, right after the expense.

## Decision
claimdesk ships as one responsive web app that works in mobile browsers.
We build no native iOS or Android app in 2026. Revisit if more than half of
claims fail on mobile browsers or when a mobile developer joins.

## Consequences
Camera capture of receipts uses the browser file input with
`capture="environment"`.
