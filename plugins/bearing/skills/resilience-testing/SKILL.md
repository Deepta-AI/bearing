---
name: resilience-testing
description: 'Tests the failure modes the design claims: fault injection plan, backup restore drills, DR tests with measured RTO and RPO. Use when asked about "chaos testing", "restore drill", "DR test" or "what if the database dies".'
argument-hint: "[plan|drill|dr|record <fault> \"<observed>\"] [--service <name>]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(ls:*), Bash(mkdir -p:*), Bash(date:*), Bash(make -n:*), Bash(docker compose config:*), Bash(kubectl get:*), Bash(git log:*)
---

# resilience-testing

A failure-mode table is a claim. This skill turns each row into a fault
with an expected behaviour, hands the engineer the command to inject it,
records what was observed, and keeps the restore date honest.

Not this: `deployment-architecture` writes the RPO, RTO and DR
claims; `incident` runs a live incident. This skill tests the claims.

## Inputs

- failure modes: section "Failure modes" of `docs/architecture/HLD.md`
  or `docs/design/*-hld.md`; if absent, ask once for the top five
  ("a dependency, a store, a disk, a certificate, a network: what fails
  and what should happen?"); nothing: stop with "0 failure modes".
- topology and stores: `docs/architecture/deployment.md` (stores,
  backups, RPO, RTO, last restore test, DR steps), compose files, `k8s/`;
  if absent, faults are written against the HLD's component names and
  every backup fact is `unconfirmed`.
- platform for tooling: compose (`docker-compose*.yml`), Kubernetes
  (`k8s/`, `helm/`), managed cloud (`terraform/`); unknown: the options
  are listed and none is chosen.
- previous runs: `docs/resilience/RESILIENCE_PLAN.md` and
  `docs/resilience/restore-drill-*.md`; appended to, never overwritten.
- observed results for `record`: the fault name and the observed text
  from the engineer; nothing else is invented.
- templates in this skill: `templates/RESILIENCE_PLAN.md`,
  `templates/restore-drill.md`.

## Steps

1. Load the failure modes. Print "N failure modes from <source>". Zero:
   stop non-zero.
2. `plan`: one fault per failure mode, plus any of the five standard
   faults the HLD lacks, written as "HLD gap": kill a dependency (stop
   the container or scale the deployment to 0), add latency (Toxiproxy
   `latency` toxic 2000 ms, or `tc qdisc add dev eth0 root netem delay
   2000ms` in the pod), fill a disk (`fallocate -l <size>` on the data
   volume to 95 percent), expire a certificate (a staging cert issued
   with `-days 1`), partition the network (Toxiproxy `timeout` toxic, or
   a NetworkPolicy denying egress). Per fault: component, injection
   command per platform, expected behaviour copied from the HLD (what
   the user sees, which alert fires, how it recovers, within how long),
   blast radius, abort condition, revert command. Write
   `docs/resilience/RESILIENCE_PLAN.md` from `templates/RESILIENCE_PLAN.md`.
   Print the fault count and the gap count.
3. `drill`: per store, the restore procedure: locate the latest backup
   (command), restore into a scratch instance (never the live one),
   verify with a row count and a checksum against the numbers recorded
   at backup time, measure wall time (that is the measured RTO), compare
   the backup timestamp with the restore start (that is the measured
   RPO). Write `docs/resilience/restore-drill-<date>.md` from
   `templates/restore-drill.md` with the fields for the engineer. When
   the numbers come back, fill them and set `Last restore test: <date>`
   on the store's row in `deployment.md` when present. Print stores
   drilled of stores.
4. `dr`: walk the DR section of `deployment.md` step by step; print each
   step's command; a step without a command is a finding. Measured RTO
   is declared loss to healthy; measured RPO is the data age at recovery.
   Claimed against measured, per scenario (zone loss, region loss).
5. Tooling, one recommendation per platform, install and smoke command
   printed, never installed here: Toxiproxy in front of Postgres and
   Redis on compose; `tc netem` inside a container for latency and loss;
   Litmus or Chaos Mesh on Kubernetes; Gremlin or AWS FIS on a managed
   cloud.
6. `record <fault> "<observed>"`: append observed text, result (pass
   only when every expected column matches), date and who ran it.
7. Print the table and the counts.

## Output contract

```
## Resilience: <repo> (N failure modes from <source>)
| Fault | Component | Injection | Expected | Observed | Result | Date |
...
Faults: N planned, R run, P pass, F fail, N-R not run   HLD gaps: G
Restore drill: <d> of <s> stores; RTO measured <t> (claimed <t>), RPO measured <t> (claimed <t>) | not run
DR test: zone RTO <m>/<c>, RPO <m>/<c>; region RTO <m>/<c>, RPO <m>/<c> | not run
Tooling: <choice> (<install command>)
Paths: docs/resilience/RESILIENCE_PLAN.md [, docs/resilience/restore-drill-<date>.md]
Next for the engineer: <injection command for the first not-run fault>
```

## Gotchas

- Never injects a fault, in any environment. The command is printed; the
  engineer runs it in a scratch or staging environment first, and in
  production only with an owner watching the abort condition.
- A backup that has never been restored is a hope. The date recorded is
  the date of a restore, and the RTO is the time it took.
- Restoring into the live instance is how a backup destroys data. Always
  a scratch instance, then a swap.
- "Degrades gracefully" is not an expectation. Name the status code, the
  fallback, the alert and the seconds to recover.
- A retry storm during a dependency kill hides the real failure mode;
  watch retry counts and queue depth while the fault is on.
- A certificate drill uses a short-lived staging cert; a production
  certificate is never touched.
- A fault that passed once is not proven; the plan carries a cadence
  (quarterly) and a re-run after every change to the component.
