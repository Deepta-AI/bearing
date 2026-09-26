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

## Faults

<!-- What: one row per HLD failure mode, plus any of the five standard faults
     (kill a dependency, add latency, fill a disk, expire a certificate,
     partition the network) the HLD lacks, listed under HLD gaps.
     Good: expected behaviour is copied from the HLD and names the status
     code, the fallback, the alert and the seconds to recover; "degrades
     gracefully" is not an expectation. Every row has an abort condition and
     a revert command. The commands are printed, never run by the skill.
     Example: the rows below; replace the <placeholders> with real names. -->

| Id | Fault | Component | Injection (command) | Expected: user sees | Expected: alert | Expected: recovery | Blast radius | Abort when | Revert (command) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| F-01 | kill dependency | <postgres> | `docker compose stop postgres` | 503 with retry-after on writes; reads from cache | `<Service>TargetDown` | reconnect within 30 s of restart | api, worker | error rate > 50% for 2 min | `docker compose start postgres` |
| F-02 | add latency | <redis> | `toxiproxy-cli toxic add -t latency -a latency=2000 redis` | p95 under 1.5 s, cache bypass | `<Service>LatencyP95High` | none needed | api | p95 > 5 s | `toxiproxy-cli toxic remove -n latency_downstream redis` |
| F-03 | fill disk | <db volume> | `fallocate -l <size> /var/lib/postgresql/data/fill` | writes fail with a clear error, reads work | `DiskUsageHigh` | alert leads to cleanup | db | disk 100% | `rm /var/lib/postgresql/data/fill` |
| F-04 | expire certificate | <ingress, staging> | issue with `-days 1`, wait | clients fail closed; renewal runs | `CertExpiresSoon` | auto-renew before expiry | all | none (staging) | reissue |
| F-05 | partition network | <api to queue> | `toxiproxy-cli toxic add -t timeout -a timeout=0 queue` | jobs buffer locally, no data loss | `QueuePublishFailing` | drain on reconnect | worker | buffer > <n> | `toxiproxy-cli toxic remove ...` |

HLD gaps (faults the HLD has no expected behaviour for): <list or none>

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
