# ADR-0001: One SQLite file for the ledger

Status: Accepted
Date: 2025-06-10

## Context

One finance host, one nightly writer, a handful of readers. The ledger
must be copyable as a single file for the auditors.

## Decision

Keep the ledger in one SQLite database in WAL mode, backed up nightly
with SQLite's online backup, never by copying the file.

## Consequences

Backups run while the sync may still be writing; a file copy could
capture a torn database, so the online backup API is required.
