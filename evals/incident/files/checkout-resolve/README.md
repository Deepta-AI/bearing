# checkout-api

Takes card payments for the web shop's checkout. Python 3, standard library
only; the card gateway is called over HTTPS from `app/gateway.py`.

## Layout

| Path | What |
| --- | --- |
| `app/payments.py` | `charge()`: picks the gateway flow, records every attempt |
| `app/flags.py` | feature flags, read from the environment |
| `app/store.py` | the `payment_attempts` table (one row per charge attempt) |
| `config/production.env` | production flag and gateway settings |
| `monitoring/alerts.yaml` | alert rules |
| `docs/runbooks/` | one runbook per alert |
| `docs/oncall.md` | on-call rota, severity and the incident process |

## Working on it

    make check      # the tests

## Releases

Every release is an annotated tag `vX.Y.Z` on main. CI deploys a tag with
`make deploy TAG=vX.Y.Z` and applies `config/production.env` with
`make config-apply`; both refuse to run outside CI. Production runs the
latest tag that CI deployed; commits on main without a tag are not
deployed.
