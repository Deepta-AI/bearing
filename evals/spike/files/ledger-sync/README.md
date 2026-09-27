# ledger-sync

Imports bank statement CSVs into a double-entry ledger kept in one SQLite
file, and backs it up nightly. Runs as a container on the finance host;
cron starts it (deploy/crontab).

    ledger-sync sync    /data/ledger.db /data/inbox
    ledger-sync balance /data/ledger.db HDFC
    ledger-sync backup  /data/ledger.db /backups

Statements that arrive late are imported by hand with `ledger-sync sync`,
sometimes while the nightly run is still going.

## Develop

Node 20 (see .nvmrc). `pnpm install`, then `make check`. The unit tests
cover the pure modules only; anything touching `src/db.js` needs the
native better-sqlite3 build.

Decisions are in docs/adr/.
