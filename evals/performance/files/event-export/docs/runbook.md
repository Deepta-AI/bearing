# Runbook: event-export

## Re-exporting an hour

If the loader reports a bad or truncated file, delete
`OUTPUT_DIR/events-<hour>.csv`. The worker's next pass (at most an hour
later) sees the file is missing and writes the complete hour again. No
restart is needed.

## Memory

The worker's memory climbs steadily and the pod is OOMKilled after about
ten hours. The cause is the account region cache (`account_region` in
export/accounts.py is an unbounded `lru_cache`). Until it is fixed,
deploy/restart-cronjob.yaml restarts the worker every six hours.

## Alerts

`EventExportMissingHour` fires when an hour older than 3 hours has no
file.
