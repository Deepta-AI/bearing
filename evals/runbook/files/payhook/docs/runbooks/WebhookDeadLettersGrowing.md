# Runbook: WebhookDeadLettersGrowing

- Service: payhook
- Severity: page
- Owner (team, on-call rotation): payments-team, payments-oncall
- Dashboard: https://grafana.example/d/payhook/payhook-queue
- Last verified: 2026-03-02

## What this alert means

More than 50 payment events were dead-lettered in the last hour
(`monitoring/alerts/webhooks.yaml`). A dead event has failed 5 attempts and
will not be tried again on its own.

## User impact

Orders whose payment event is dead stay on "Awaiting payment" and are not
released to fulfilment until the event is replayed.

## Diagnosis

1. `make queue-stats`. Healthy: `dead_by_error` empty or a handful.
   Unhealthy: hundreds under one error.
2. Check the Orders API dashboard for 5xx.

## Remediation

1. Replay the dead letters: `make replay-dlq`. Confirm: `make queue-stats`
   shows `dead_by_error` empty.
2. If they die again, check the Orders API.

## Rollback

`make rollback PREV_TAG=<previous release tag>` if a deploy preceded the
alert.

## Escalation

After 30 minutes, page `payments-secondary`; post in `#inc-payments`.

## After

Write the incident up under `docs/incidents/`.
