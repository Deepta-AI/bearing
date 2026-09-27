---
name: resilience-testing
description: 'Tests the failure modes the design claims: fault injection plan, backup restore drills, DR tests with measured RTO and RPO. Use when asked about "chaos testing", "restore drill", "DR test" or "what if the database dies".'
argument-hint: "[plan|drill|dr|record <fault> \"<observed>\"] [--service <name>]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(ls:*), Bash(mkdir -p:*), Bash(date:*), Bash(make -n:*), Bash(docker compose config:*), Bash(kubectl get:*), Bash(git log:*)
---

# resilience-testing

A failure-mode table, an RPO and a "last restore test" date are claims.
This skill turns each claim into a test an engineer can run, and first
predicts the result from the repository: most claims fail on paper before
anyone injects a fault, and those findings are worth more than the plan.

Not this: `deployment-architecture` writes the RPO, RTO and DR
claims; `incident` runs a live incident. This skill tests the claims.

## Inputs

- mode: `plan` (faults), `drill` (backup restore), `dr` (DR walk),
  `record`. Pick from the request: "restore", "backup", "RPO" mean drill.
- claims: the "Failure modes" section of `docs/architecture/HLD.md` or
  `docs/design/*-hld.md`; the store table and DR section of
  `docs/architecture/deployment.md`; runbooks under `docs/runbooks/`.
- the truth to check claims against: code (timeouts, error mapping,
  health handlers, retries, side effects), manifests (probes, per
  environment config, backup jobs, database config), alert rules,
  compose files, scripts. Read these before writing a single expectation.
- previous runs: `docs/resilience/`; appended to, never overwritten.
- templates: `templates/RESILIENCE_PLAN.md`, `templates/restore-drill.md`.

Missing claims do not stop the run. No HLD: derive the failure modes from
the dependencies the code actually calls (every store, queue and external
API) and mark each "no claim, proposed". A drill needs only the stores,
from deployment.md or the manifests. Stop only when the repository names
no dependency and no store at all, and print "0 dependencies found".

## Steps

1. **Inventory.** List every dependency the code calls and every store,
   with where each runs per environment. Resolve each environment's real
   host from its overlay or config file, not from the docs. Print
   "N dependencies, S stores, from <sources>".
2. **Blast radius per environment.** If staging (or any test
   environment) points at a host, bucket or cluster that production also
   uses, a fault on that resource is a production fault. Say so first.
   Faults on a shared resource are rewritten to act only on the test
   environment's own path to it (egress NetworkPolicy in the staging
   namespace, a proxy in front of it, DNS override), moved to a local
   instance, or blocked until the environment has its own. Never plan to
   stop, fill, restart or partition the shared resource itself.
3. **Predict from the repo, per claim** (the step a generalist skips).
   For each failure mode write Claimed (from the doc), Predicted (from
   code and config, with file and line) and a verdict: holds, fails, or
   unknown. Check at least:
   - Health checks: what does the readiness and liveness handler test? A
     probe that pings a dependency turns that dependency's outage into
     every pod leaving the Service (readiness period x failureThreshold
     seconds) and restarting (liveness period x failureThreshold),
     taking down endpoints that do not need the dependency. Compute the
     seconds from the manifest.
   - Error mapping: the status code the handler really returns on that
     dependency's error, and whether the documented fallback exists
     (a cache error that returns 500 has no fallback).
   - Timeouts: client, query, server read and write, ingress. A fault
     that slows a dependency must exceed the claimed bound and reach
     the configured timeout, or it proves nothing; state both numbers.
   - Refused versus silent: a stopped process refuses connections fast;
     a partition drops packets and every call hangs until some timeout
     fires. Code with no query or dial timeout hangs, exhausts its pool,
     and queues. Plan both kinds where they would differ.
   - Side effects across the fault: an external call that commits (card
     authorisation, email, message publish) followed by a local write
     that can fail leaves an orphan (a hold with no order). A client
     timeout does not mean the remote call failed; without an
     idempotency key a retry doubles it. Name the compensation or its
     absence, and add the check (orphans in the provider's sandbox).
   - Alerts: every alert the claim names exists in the rules, with its
     `for:` and severity; "pages within 1 minute" needs a paging rule
     whose window plus `for:` fits. An alert computed from the service's
     own request metrics goes silent when the pods are out of rotation:
     the errors are served by the ingress and the unready pods may not be
     scraped. Say which alert would really fire, if any.
   - Retries and queues: a retry storm during a kill hides the real
     failure; name the counter to watch.
4. **`plan`.** One fault per failure mode and per unclaimed dependency.
   Per fault: component, injection command per platform, expected
   behaviour (status code or header, the alert by name, seconds to
   recover), the prediction and verdict from step 3, blast radius naming
   the environments it touches, abort condition, revert command. Where
   the claim gives no recovery time, propose one in seconds and mark it
   proposed. An external provider is never broken at the provider:
   inject on the service's side (egress policy, proxy, DNS). A
   hypothesis with no injection you can write is a finding, not a fault
   row. Order the runs so faults predicted to fail are fixed or
   accepted first; running a fault already known to fail only measures
   the outage. Write `docs/resilience/RESILIENCE_PLAN.md` from the
   template. Observed and result fields stay empty.
5. **`drill`.** Before the procedure, audit the backup:
   - Coverage: what the job really dumps (`-n`, `-t`, `--exclude`,
     database list) against every schema and table in the migrations.
     A schema outside the dump is data no backup holds.
   - Does it run: client version against server major (pg_dump refuses
     a newer server major), `set -e` and failure alerting on the job,
     and whether retention by count hides a job that stopped (seven old
     dumps still "look healthy" in a listing).
   - RPO basis: continuous archiving claimed? Check `archive_mode`,
     `archive_command` and the runbook history. Without it the RPO is
     the dump interval plus the dump duration, and more when a night
     fails.
   - RTO plausibility: download plus restore plus index build of the
     on-disk size, against the claim. A restore usually takes longer
     than the dump; say when the claim looks unreachable.
   - History: is the recorded "last restore test" a restore? A bucket
     listing or a size check is not.
   - Restore tooling: read any existing restore script's default
     target; one that defaults to the live URL with `--clean` drops live
     tables. The drill's own restore command names the scratch target
     explicitly and runs from a pod or shell that holds no live
     credentials.
   Then the procedure, one pasteable command per step: locate the newest
   backup and its snapshot time; provision a scratch instance of the
   same major version, sized for the on-disk database (not the dump),
   isolated from app traffic; restore (roles and grants are not in a
   single-database dump: use `--no-owner --no-acl` or restore globals);
   verify per table, naming every schema, against a reference fixed at
   the snapshot time (counts recorded at dump time, or live counts
   limited to rows created before the snapshot); smoke query; tear down
   and delete the copy (it is production data). RTO is recovery start
   to verified database; RPO is the snapshot time against the simulated
   loss. Write `docs/resilience/restore-drill-<date>.md` from the
   template. Set `Last restore test` only after a real restore; a wrong
   date may be corrected to "never".
6. **`dr`.** Walk the DR section step by step; each step's command, or
   the missing command as a finding. Claimed against measured per
   scenario (zone loss, region loss).
7. **Tooling**, recommended with its install and smoke command, never
   installed: Toxiproxy or `tc netem` on compose; Chaos Mesh or Litmus
   on Kubernetes, or a NetworkPolicy for a partition; Gremlin or AWS FIS
   on a managed cloud. Drill manifests the engineer will apply go under
   `docs/resilience/`, not into the deploy tree.
8. **`record <fault> "<observed>"`**: append the engineer's text, the
   result (pass only when every expected column matches), date, who ran
   it.

## Output contract

The final message leads with what the repository already says about the
outcome, most consequential first, each with file and line; then:

```
## Resilience: <repo> (N dependencies, S stores, from <sources>)
Predicted to fail before running: <claim -> reason>, ...
| Fault | Component | Injection | Expected | Predicted | Observed | Result |
Faults: N planned, 0 run | R run, P pass, F fail
Restore drill: prepared, not run | RTO <m> (claimed <c>), RPO <m> (claimed <c>)
Paths: docs/resilience/RESILIENCE_PLAN.md [, docs/resilience/restore-drill-<date>.md]
Next for the engineer: <the first thing to fix or run>
```

## Gotchas

- Never injects a fault, never connects to a real store, never runs a
  restore script. Commands are printed for a scratch or staging
  environment, production only with an owner watching the abort.
- The gaps are findings. In a request for a plan or drill, leave code,
  manifests and backup jobs unchanged unless asked; propose the fix.
- Nothing is reported as observed until the engineer ran it. A local
  rehearsal on fakes or synthetic data is labelled as such.
- "Degrades gracefully" is not an expectation. Name the code, the
  alert, the seconds.
- A fault that passed once is not proven; the plan carries a cadence
  (quarterly) and a re-run after every change to the component.
