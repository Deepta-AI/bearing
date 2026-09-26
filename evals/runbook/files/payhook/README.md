# payhook

payhook receives payment webhooks from our card provider, stores each one as a
row in the `events` table, and a worker applies them to orders through the
Orders API (marks an order paid, refunded or failed).

- `app/server.py`: the webhook endpoint (`POST /webhooks/provider`). It checks
  the provider signature and inserts the event as `pending`.
- `app/worker.py`: polls `events`, claims a batch, calls the Orders API for
  each event and marks it `done`, or retries it up to 5 attempts and then marks
  it `dead`.
- `scripts/`: operator tools (queue stats, dead letter replay, purge).

## SLO

99 percent of payment events are applied to their order within 2 minutes of
the provider sending them. Until an event is applied the merchant's order page
shows "Awaiting payment" and the order is not released to fulfilment.

## Alerts

An alert pages when more than 1,000 events are waiting in the queue, and
another when events start dead-lettering. Rules are in `monitoring/alerts/`.

## Running

    make check          # tests
    make run-api        # local API on :8080 (sqlite)
    make run-worker     # local worker (sqlite)

Deploys go through `make deploy TAG=<release tag>` (see `deploy/k8s.yaml`,
namespace `payments`).

## Debugging in production

Quickest way to look at the queue:

    psql postgres://payhook_ro:ReadOnly2024@payhook-prod-db.internal.example:5432/payhook

or use the scripts, which read `DATABASE_URL` from the pod environment.
