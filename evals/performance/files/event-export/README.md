# event-export

Long-running worker that writes each hour of product events to a CSV file
for the analytics team's loader. Every pass it looks at the last 24 hours
and exports each hour whose file is missing from the output directory.

- Input: the `events` and `accounts` tables of the events database
  (SQLite in development, `EVENTS_DB`).
- Output: `OUTPUT_DIR/events-<hour>.csv`, for example
  `events-2026-09-20T13.csv`, columns
  `event_id,account_id,region,kind,created_at,payload`, ordered by
  `created_at` then `event_id`.
- Events arrive at least once, so the same `event_id` can appear more
  than once. The `hour` column is the hour of the event's own
  `created_at`, set by the producer, so a redelivered duplicate always
  lands in the same hour as the original. Each file must contain each
  event once.

Python 3.12, standard library only. `make check` runs the tests,
`make run` starts the worker (both use `python3.12`; override with
`PYTHON=...`).

See docs/runbook.md for operations and docs/sizing.md for volumes.
