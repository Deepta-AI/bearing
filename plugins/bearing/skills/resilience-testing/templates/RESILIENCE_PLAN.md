# Resilience plan: <repo>

Source of failure modes: docs/architecture/HLD.md section "Failure modes" | asked
Platform: compose | kubernetes | managed cloud   Tooling: <Toxiproxy | tc netem | Litmus | Chaos Mesh | Gremlin | AWS FIS>
Cadence: quarterly, and after any change to a component below   Owner: <rotation>

<!-- Template guidance: every section below carries a comment saying what goes
     there (What), what a strong entry has (Good) and a one-line example
     (Example). Delete each comment when you fill its section. The plan turns
     each HLD failure mode into a fault an engineer can inject, with the
     behaviour expected, and keeps the dated record of what was observed.
     Runs, drills and DR tests are appended to, never overwritten. -->

## Predicted before running

<!-- What: each claim checked against code and config before any fault is
     injected: claimed, predicted (file and line), verdict holds | fails |
     unknown. Shared resources between environments come first.
     Good: probe seconds computed from the manifest, the real status code
     from the handler, alerts looked up in the rules with their for:.
     Example: | Postgres down | 503 + Retry-After | 500 (handler.go:98); all
     pods unready after 10 s (readiness 2 x 5 s) | fails | -->

| Claim | Claimed | Predicted (evidence) | Verdict |
| --- | --- | --- | --- |

## Faults

<!-- What: one row per failure mode and per dependency the claims skip.
     Good: expected behaviour names the status code, the alert and the
     seconds to recover (proposed when the claim has none); an injected
     delay exceeds both the claimed bound and the configured timeout;
     external providers are faulted on this side of the connection;
     every row has an abort condition and a revert command. The commands
     are printed, never run by the skill.
     Example: the rows below; replace the <placeholders> with real names. -->

| Id | Fault | Component | Injection (command) | Expected: user sees | Expected: alert | Expected: recovery | Predicted | Blast radius | Abort when | Revert (command) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| F-01 | refuse (stop) | <postgres, local compose> | `docker compose stop postgres` | 503 with Retry-After on writes | `<Service>DBUnavailable` | reconnect within 30 s | fails: handler returns 500 | local only | n/a | `docker compose start postgres` |
| F-02 | silent drop | <postgres path, staging ns> | NetworkPolicy denying egress to 5432 from `app=<api>` | as F-01 within <client timeout> s | as F-01 | 30 s after removal | hangs: no query timeout | staging pods only | 5xx > 50% for 2 min | remove the NetworkPolicy |
| F-03 | slow external | <psp egress> | proxy latency above the claimed bound and the client timeout | 502 within <claimed> s | `<Service>HighErrorRate` | 60 s (proposed) | fails: client timeout <t> s | staging | p99 > 60 s | remove the toxic |

Findings that are not faults (no injection possible, or already known): <list or none>

## Runs

<!-- What: one row per time a fault was injected: where, by whom, what was
     observed and the result.
     Good: Observed is the engineer's own text; Result is pass only when
     every expected column matched; a fault run once is not proven.
     Example: | F-01 | 2026-09-18 | staging | on-call (platform) | writes 503
     with retry-after, alert fired at 40 s, reconnect 12 s after start | pass | -->

| Fault | Date | Environment | Run by | Observed | Result |
| --- | --- | --- | --- | --- | --- |

## Restore drills

<!-- What: one row per store restored, linking the dated restore-drill doc
     and the measured RTO and RPO.
     Good: the date is the date of a restore into a scratch instance, not of
     a backup; RTO is the wall time it took.
     Example: | postgres | 2026-09-12 | docs/resilience/restore-drill-2026-09-12.md
     | 41 min | 6 h 10 min | pass | -->

| Store | Date | Restore doc | RTO measured | RPO measured | Result |
| --- | --- | --- | --- | --- | --- |

## DR tests

<!-- What: one row per DR scenario walked (zone loss, region loss), claimed
     against measured.
     Good: measured RTO runs from declared loss to healthy, measured RPO is
     the data age at recovery; a DR step without a command is a finding.
     Example: | zone loss | 2026-08-30 | 30 min | 52 min | 5 min | 3 min |
     step 4 (DNS failover) had no command | -->

| Scenario | Date | RTO claimed | RTO measured | RPO claimed | RPO measured | Findings |
| --- | --- | --- | --- | --- | --- | --- |
