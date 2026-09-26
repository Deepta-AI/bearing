# payout emails sent twice, rough notes (on-call)

- Thu night, around midnight, partner success pinged: partners getting the
  "payout sent" email 2 or 3 times
- forwarded examples: accounts@brightlane-traders.example,
  ops@kaveri-foods.example, and one partner called support from +91 98450 12345
- about 40 partners hit I think
- provider dashboard shows each duplicate as a separate accepted message.
  provider status page said "degraded latency" 23:30 to 00:30 IST
- my guess: provider bug, they sent dupes
- also Dev Three bumped retries to 3 in yesterday's release, which he
  shouldn't have done without asking
- a bit later: set NOTIFY_MAX_RETRIES=1 on the batch host by hand
  (export in the crontab env), reran nothing
- batch had already finished by then anyway
- money is fine: checked the ledger, 312 payouts and 312 transfers, nothing
  paid twice
- used NOTIFY_API_KEY=nt_live_4b1f8e0a92c7d3e6a1 to pull the export from the
  provider API (rotate?)
- export of everything the provider accepted that night:
  ops/provider-accepted-2026-09-24.csv
- TODO: monitoring
