# billingsvc

Plans and charges for the people who pay us. Product, support and finance
all call them customers; the code still says `Client` from the first
prototype.

## Layout

- `billing/`: the domain package (`Client`, `Store`, the payment gateway,
  monthly statements, see `docs/statements.md`).
- `api/`: the HTTP API, see `docs/api.md`.
- `cmd/billingd/`: the server.

## Consumers

The reporting service (a separate repository) imports `billing` directly:
it uses `billing.Client`, `billing.NewStore`, `(*billing.Store).Client`,
`(*billing.Store).ActiveClients` and `billing.ErrClientNotFound`. It pins
this module by version and upgrades when we tag.

## Running

    make check
    make build && ./billingd -data data/clients.json

The data file is written by the nightly export from the main database; its
field names follow the database columns.
