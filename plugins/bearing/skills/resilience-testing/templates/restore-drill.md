# Restore drill: <store> on <YYYY-MM-DD>

Run by: <name>   Environment: scratch instance <name> (never the live store)
Backup mechanism: <snapshot | pg_dump | WAL archive | managed backup> (deployment.md | unconfirmed)
Claimed: RTO <t>, RPO <t>

<!-- Template guidance: every section below carries a comment saying what goes
     there (What), what a strong entry has (Good) and a one-line example
     (Example). Delete each comment when you fill its section. One drill
     proves one store's backup can be restored into a scratch instance and
     measures the real RTO and RPO against the claims above. The engineer
     runs the commands and fills the times; nothing is invented. -->

## Before the drill

<!-- What: what the repository already says about the backup, checked
     before anyone restores: coverage, whether the job still succeeds, the
     RPO basis, RTO plausibility, whether the last "restore test" was one,
     and the default target of any existing restore script.
     Good: each line cites the file; a schema missing from the dump or a
     client older than the server major is stated as the likely result.
     Example: "Dump runs pg_dump -n public; billing schema (migration 0003)
     is in no backup." -->

- Coverage (schemas and tables dumped vs migrations):
- Job health (client vs server version, failure alert, newest backup age):
- RPO basis (WAL archiving on? dump interval and duration):
- RTO plausibility (download + restore + index build vs claim):
- Previous "restore test" (a restore, or a listing?):
- Existing restore tooling (default target, --clean):

## Procedure

<!-- What: the commands to locate the latest backup, restore it into a
     scratch instance, verify it and tear it down, with start and finish
     times in UTC.
     Good: every step has a command someone can paste; the restore target is
     never the live instance; the restore command names the scratch
     target explicitly and runs with no live credentials; verification
     names every schema and compares against a reference fixed at the
     snapshot time (counts recorded at dump time, or live counts of rows
     created before the snapshot).
     Example: | 3. Restore | `pg_restore -d drill_0912 -j 4 latest.dump` |
     09:14 | 09:47 | 33 min, 2 warnings on extension owner | -->

| Step | Command | Started (UTC) | Finished (UTC) | Notes |
| --- | --- | --- | --- | --- |
| 1. Locate latest backup | `<list backups command>` | | | backup taken at <UTC> |
| 2. Provision scratch instance | `<command>` | | | |
| 3. Restore | `<restore command>` | | | |
| 4. Verify row counts | `<count query>` vs recorded <n> | | | |
| 5. Verify checksum | `<checksum command>` vs recorded <sum> | | | |
| 6. Application smoke test | `<one request against the scratch>` | | | |
| 7. Tear down and delete the copy | `<command>` | | | |

## Measured

<!-- What: the RTO and RPO this drill measured and what data was verified.
     Good: RTO is step 2 start to step 6 pass; RPO is backup time to restore
     start; both are numbers with units, next to the claims above.
     Example: "RTO 41 min (claimed 60 min); RPO 6 h 10 min (claimed 24 h);
     18,402,311 rows in 37 tables, checksum match: yes." -->

- RTO (step 2 start to step 6 pass): <t>
- RPO (backup taken at, to restore start): <t>
- Data verified: <n> rows in <k> tables, checksum match: yes | no

## Result

<!-- What: pass or fail, and for a fail what did not match with the
     follow-up task id.
     Good: a fail names the step and the number that differed; the
     deployment.md line is updated only after a real restore.
     Example: "fail: orders count 1,204 short of recorded; PAY-OP-412 to
     include the orders_archive schema in the dump." -->

pass | fail: <what did not match, and the follow-up task id>

Recorded in docs/architecture/deployment.md: `Last restore test: <date>` (updated | file absent)
