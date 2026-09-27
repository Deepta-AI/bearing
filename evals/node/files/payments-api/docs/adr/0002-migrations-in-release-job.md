# ADR-0002: Migrations run in the release job

Status: Accepted (2026-04-10)

Migrations are generated with `make migrate-new` (drizzle-kit generate), so
the SQL file, `drizzle/meta/_journal.json` and the snapshot always move
together; the migrator only applies what the journal lists. They are applied
by `make migrate` in the release job before the new version rolls out. The
service never migrates on startup: 3 replicas start together and a failed
migration would crash-loop every pod.
