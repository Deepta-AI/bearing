# Runbook: <job> backlog or dead letters

<!-- Template guidance: every section below carries a comment saying what goes
     there (What), what a strong entry has (Good) and a one-line example
     (Example). Delete each comment when you fill its section. This is the
     stub background-jobs leaves for one job's backlog and dead-letter alerts,
     read by the on-call engineer while it fires; runbook extends it. -->

- Service: <service>
- Severity: <sev>
- Owner (team, on-call rotation): <rotation>
- Dashboard: <panel>
- Last verified: <YYYY-MM-DD>

## What this alert means

<!-- What: the two alert conditions for this queue, with their thresholds.
     Good: the queue name and numbers match the JOBS.md Metrics row and the
     alert rule exactly, so a grep finds all three.
     Example: "`jobs_oldest_age_seconds{queue=\"email\"}` above 300 for 5
     minutes." -->

`jobs_oldest_age_seconds{queue="<queue>"}` above <s>, or
`jobs_dead_letter_total{queue="<queue>"}` above 0. The queue is not
keeping up, or a message cannot be processed.

## User impact

<!-- What: what a user waits for, or never receives, while this fires.
     Good: names the visible symptom and how long before it matters, from
     the effect in JOBS.md; not "jobs are delayed".
     Example: "Customers do not receive invoice emails; after 1 hour
     support starts getting 'where is my invoice' tickets." -->

<what a user waits for or does not receive while this fires>

## Diagnosis

<!-- What: numbered checks that tell a stuck worker, poison and a slow
     dependency apart.
     Good: every step is a pasteable query or command plus what healthy and
     unhealthy output look like; reading the dead letter shows the last
     error and the attempt count.
     Example: "`kubectl logs deploy/email-worker --since=15m | grep
     Poison`" -->

1. Depth versus age: `<query>`. Age growing with flat depth means a
   stuck worker; both growing means the producer outran the workers.
2. Last errors: `<command to read the dead letter or the failed log>`.
   One error class repeated is poison; many classes is a dependency.
3. Worker health: `<command>`; a worker at 0 processed since restart
   is stuck on a job past its visibility timeout.

## Remediation

<!-- What: one numbered fix per cause from Diagnosis, most likely first.
     Good: each step ends with how to confirm it worked; a poison message is
     replayed or archived with the reason, never deleted or purged.
     Example: "Scale workers: `kubectl scale deploy/email-worker
     --replicas=6`. Confirm: oldest age falls below 60 s within 10 min." -->

1. Poison: read the message, fix or skip it, replay: `<command>`.
   Confirm: dead letter count back to 0.
2. Dependency down: stop the workers `<existing command>`, follow that service's
   runbook, resume. Confirm: age falls.
3. Throughput: scale workers `<command>`. Confirm: age falls within
   <minutes>.

## Rollback

<!-- What: how to revert the last worker deploy if it caused this.
     Good: the exact command and the check that it took; says that in-flight
     jobs are redelivered, so the idempotency key must hold across versions.
     Example: "`kubectl rollout undo deploy/email-worker`, then confirm the
     previous image tag in `kubectl get deploy -o wide`." -->

<how to revert the last worker deploy; jobs in flight are redelivered>

## Escalation

<!-- What: who to page next and after how long.
     Good: a named rotation and a number of minutes, not "if it persists".
     Example: "billing-oncall in PagerDuty, after 20 minutes without the
     oldest age falling." -->

<rotation>, after <minutes> without the age falling.

## After

<!-- What: what to record once the alert clears.
     Good: the cause goes in the incident doc with the message id; a poison
     message becomes a bug with a task id.
     Example: "Poison from a null `customer.email`: bug BIL-BG-311 filed,
     message 01J9Z3K8 replayed after the fix." -->

Record the cause in the incident doc; a poison message is a bug to file.
