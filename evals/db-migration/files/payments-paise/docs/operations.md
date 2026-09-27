# Operations notes

## Sizes (1 September 2026)

- payments: about 2.4 million rows, growing 110 thousand a month.
- customers: 61 thousand rows.

## Write lock

SQLite allows one writer. The app waits `busy_timeout` (5 s, app/db.py) for
the write lock and then fails the request with "database is locked".
Checkout records a payment about 15 times a second at peak.

## Incident, 14 July 2026

Migration 0005 filled `payments.method` with one `UPDATE payments SET ...`
over the whole table. It held the write lock for about 11 seconds and
checkout returned errors for every payment attempted in that window. Fills
of existing rows since then run in batches of at most 5,000 rows per
transaction.

## Full-table rewrites on the server

The server's database sits on a network volume. The `VACUUM` of 12 August
2026 rewrote the payments table (2.3 million rows then) in about 40
seconds, and checkout failed for the whole of it. A laptop does the same
rewrite in under 2 seconds, so local timings do not carry over.
