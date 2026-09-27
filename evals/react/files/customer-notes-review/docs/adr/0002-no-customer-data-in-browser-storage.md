# ADR-0002: No customer data in browser storage

Status: Accepted (2026-05-19)

## Context

Support agents work in shifts on shared machines in the contact centre, often
under one operating-system login. An audit found customer emails and phone numbers
left in localStorage by an older tool.

## Decision

The console keeps customer data in memory only. Nothing about a customer (profile
fields, orders, notes, drafts) is written to localStorage, sessionStorage,
IndexedDB or cookies. UI preferences that name no customer (sidebar open, table
density) may be persisted.

## Consequences

Reloading the page refetches from the API. Drafts are lost on reload; that is
accepted.
