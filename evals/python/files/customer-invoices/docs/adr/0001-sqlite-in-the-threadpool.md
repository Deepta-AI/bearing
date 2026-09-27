# 0001. SQLite through sqlite3, every call in the threadpool

Status: Accepted (2026-03-02)

## Context

The API serves one finance dashboard with low write volume. We want one
file to back up and no database server to run yet. The standard library
`sqlite3` driver is synchronous.

## Decision

Keep SQLite and the standard `sqlite3` module. All database access goes
through `app.db.Database`, whose methods run the blocking driver call in
FastAPI's threadpool (`run_in_threadpool`), one connection per call. No
route or service touches `sqlite3` directly, and no `async def` path makes
a blocking call on the event loop.

SQL lives only in `app/<resource>/repository.py`, always with `?`
placeholders.

## Consequences

Moving to Postgres later changes `app/db.py` and the repositories only.
