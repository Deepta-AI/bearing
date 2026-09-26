-- Down for 0000_init.sql. drizzle-kit is forward-only, so make migrate-verify
-- applies this file and removes the journal row. Down loses: the probe rows.
DROP TABLE IF EXISTS "schema_probe";
