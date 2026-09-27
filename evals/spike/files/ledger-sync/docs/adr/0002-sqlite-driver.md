# ADR-0002: better-sqlite3 as the SQLite driver

Status: Accepted
Date: 2025-08-21

## Context

We need a synchronous SQLite driver with transactions, user-defined SQL
functions (memo rules are regular expressions matched in SQL through a
REGEXP function) and the online backup API (ADR-0001).

## Options

- better-sqlite3: all three; native module compiled per platform.
- node:sqlite (Node 22.5): built in, but it has no user-defined functions
  and no backup API, and it is behind the --experimental-sqlite flag.
- sqlite3 (async): callback API, no synchronous transactions.

## Decision

better-sqlite3.

## Consequences

The image needs a compiler toolchain on Alpine. Revisit when node:sqlite
supports user-defined functions and online backup without a flag.
