# ADR-0003: Customer personal data is limited to phone number and first name

Status: Accepted, 2026-08-11

## Context
The client's data protection officer approved the programme on the basis
that we hold the minimum needed to run it.

## Decision
A member record holds the phone number (the login and the till lookup key)
and a first name. Any new personal data field needs the data protection
officer's written sign-off and a new ADR before it is built.

## Consequences
No email address, date of birth, address or gender is stored.
