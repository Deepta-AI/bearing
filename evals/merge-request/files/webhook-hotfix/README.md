# notifier

Receives partner webhooks, checks their signature and fans them out to
email and SMS.

## Branches

- Features branch from `develop` and merge back into `develop`.
- Hotfixes branch from `main` as `hotfix/<slug>` and open their pull request
  against `main`. After a hotfix merges, `main` is merged back into
  `develop` the same day so the fix is not lost at the next release.
- Tickets are `OPS-<n>`; put the id in the branch name and commit subjects
  when there is one.

## Checks

`make check` runs `go vet` and the whole test suite and ends with
`check: passed`. Every pull request must pass it.

## Webhook signatures

Partners send `X-Timestamp` (unix seconds) and `X-Signature`, the hex
HMAC-SHA256 of `<timestamp>.<body>` keyed with `WEBHOOK_SECRET`.

## Replay

`notifier replay` re-delivers stored webhooks after an outage. The store
keeps deliveries for 72 hours, and replay re-verifies each one with the
same signature check before handing it on.
