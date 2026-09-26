# Incident 2026-09-22: payment events dead-lettered after provider secret rotation

Severity: 2. Duration: 23:08 to 00:41 (1 h 33 min). Written by the on-call
engineer on 23 Sep from shell history and chat; commands are as remembered.

## Summary

The card provider rotated our webhook signing secret at 23:00 without the
notice reaching us. Every webhook after that failed the signature check and
was stored dead with `signature_invalid`. About 3,900 payment events were not
applied to orders for up to 93 minutes.

## Timeline (IST)

- 23:08 WebhookDeadLettersGrowing pages Sam (payments-oncall).
- 23:14 Following the runbook, Sam runs `make replay-dlq`. It reports
  `replayed 1204 events`. The worker applies them.
- 23:16 New events keep dying at about 40 a minute; the alert fires again.
- 23:16 to 23:30 Following the runbook's step 2, Sam spends fifteen minutes on
  the Orders API dashboards looking for 5xx. The Orders API was healthy the
  whole time.
- 23:30 `make queue-stats` output:

      {
        "dead_by_error": {"signature_invalid": 1431},
        "in_progress": 20,
        "oldest_pending_seconds": 3.1,
        "pending": 18
      }
- 23:35 Sam queries the database directly:

      psql postgres://payhook_ro:ReadOnly2024@payhook-prod-db.internal.example:5432/payhook \
        -c "select last_error, count(*) from events where status = 'dead' group by 1"

  and sees `signature_invalid` growing by about 40 a minute.
- 23:40 Sam calls Alex (payments lead) directly on the phone. Alex remembers
  a provider email about secret rotation.
- 23:58 New secret read from the provider portal and written to the
  `payhook-provider` secret; `kubectl -n payments rollout restart
  deploy/payhook-api`.
- 00:04 New webhooks verify again; dead letters stop growing.
- 00:12 Replay of the signature failures:
  `kubectl -n payments exec deploy/payhook-worker -- python3 scripts/replay_dead.py --kind signature_invalid`
- 00:41 Queue drained, alerts resolve.

## What went wrong

- The runbook's first remediation replays everything before anyone looks at
  why events died. The cause kept producing dead letters and the replay
  bought nothing.
- The runbook's description of the alert did not match the rule, so Sam
  thought the threshold was much higher than 40 a minute.
- Step 2 of the runbook sent us to the Orders API, which had nothing to do
  with it; `signature_invalid` was the only error from the start.

## Action items

- AI-1: Runbook: diagnose by error before replaying anything. Owner: payments-team.
- AI-2: Get provider rotation notices to the payments-team mailbox. Owner: payments-team.
- AI-3: payhook cannot accept the old and the new secret at the same time, so
  every rotation drops events until we update the secret. Add dual-secret
  support. Owner: payments-team.
- AI-4: Next time, call Alex straight away for anything provider related.
