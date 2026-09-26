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

## Procedure

<!-- What: the commands to locate the latest backup, restore it into a
     scratch instance, verify it and tear it down, with start and finish
     times in UTC.
     Good: every step has a command someone can paste; the restore target is
     never the live instance; row counts and checksum are compared with the
     numbers recorded at backup time.
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
| 7. Tear down | `<command>` | | | |

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
