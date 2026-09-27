# Runbook: LedgerApiHigh5xx

1. Open the ledger-api dashboard and check which route fails.
2. `kubectl -n ledger-prod logs deploy/ledger-api --since=15m | grep level=ERROR`.
3. If the errors are database timeouts, check Cloud SQL CPU and connections.
4. Roll back with the pipeline's previous tag job if a deploy in the last hour
   lines up with the start of the errors.
