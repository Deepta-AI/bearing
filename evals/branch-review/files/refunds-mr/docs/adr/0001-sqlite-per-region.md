# ADR-0001: SQLite per region

Status: Accepted

## Decision

Each region runs one single-threaded writer process over a SQLite database,
so requests that write are handled one at a time, in arrival order.
Handlers get a connection from the caller and commit their own writes.
