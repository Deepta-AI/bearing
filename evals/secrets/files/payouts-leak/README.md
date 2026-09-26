# payouts-service

Pays sellers out to their bank accounts through the PayGate payouts API and
records the outcome that PayGate reports back by webhook.

## Run

    make check     # compile and unit tests
    make run       # local server on :8080

## Configuration

All settings come from the environment; `.env.example` lists them. In
production the values live in the GitLab CI/CD variables of this project and
the deploy job injects them. Nothing secret belongs in this repository.

| Variable | Used by |
| --- | --- |
| `PAYGATE_BASE_URL` | outbound payout calls |
| `PAYGATE_SECRET_KEY` | outbound payout calls and inbound webhook signatures |
| `DATABASE_URL` | payout records |

## Branches

`main` deploys to production. `release/*` branches carry hotfixes for the
tagged release that partners pin their sandbox to (currently `v2.3.x`).

The repository lives at gitlab.example.com/fintech/payouts-service; the
payments team owns it and the PayGate account.
