# wallet

Customer wallets for the storefront. Customers top up through the payment
provider; the provider tells us about each payment with a webhook, and we
credit or debit the wallet.

- `app/server.py` is the HTTP entry point (stdlib `ThreadingHTTPServer`).
- `app/webhooks/` receives the provider's webhooks at
  `POST /webhooks/provider`.
- `app/wallet.py` holds balances in integer paise.
- `docs/provider-webhooks.md` is our summary of the provider's webhook
  contract.
- `scripts/purge_events.py` trims the processed events table; cron runs it
  (`deploy/crontab`).

## Configuration

| Variable | Meaning |
|---|---|
| `WEBHOOK_SECRET` | Signing secret from the provider dashboard. The service refuses to start without it. |
| `DB_PATH` | SQLite file, default `wallet.db` |

## Status

The webhook receiver is built but switched off in production: the provider
dashboard still points at the old PHP endpoint. We switch the URL over once
this code is reviewed.

## Checks

    make check    # pytest
