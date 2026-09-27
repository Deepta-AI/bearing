# Feature flags register

Every flag in `internal/flags` has one row here (ADR 0002). Owner is the
team's on-call rotation. Target date is when the flag is removed.

| Flag | Default | Owner | On means | Removal ticket | Target date | Added |
| --- | --- | --- | --- | --- | --- | --- |
| audit_log_v2 | off | reports-oncall | report reads are written to the v2 audit log | REP-174 | 2026-06-30 | 2026-04-01 |
| saved_filters | off | reports-oncall | customers can save report filters | REP-205 | 2026-11-20 | 2026-08-22 |
