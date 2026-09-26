---
name: runbook
description: 'Writes or updates the runbook for one alert: meaning, impact, diagnosis commands, remediation, rollback, escalation. Use when asked to "write a runbook", "document this alert" or "what do we do when X fires".'
argument-hint: "<alert name> [service] [--from-incident <incident doc>]"
context: fork
agent: doc-writer
allowed-tools: Read, Write, Grep, Glob
---

# runbook

An alert without a runbook is noise with a pager attached.

## Inputs

- Alert name: `$1`; if absent, one question: "which alert, as it fires?".
  Nothing: stop with "provide the alert name".
- Alert definition: looks in `monitoring/alerts/*.yaml`, Prometheus rule
  files, Grafana or Datadog exports found by grep on the name; if absent,
  the user's description of the condition, and the runbook notes "alert
  rule: not in this repository".
- Service facts (entrypoints, dashboards, dependencies): looks in the
  CLAUDE.md snapshot; if absent, README, Makefile, Dockerfile, compose
  files and `docs/design/*-hld.md`; if still unknown, placeholders in
  angle brackets that the report lists as open.
- Template: `docs/templates/RUNBOOK.md` when present, else
  `templates/RUNBOOK.md` in this skill's folder.
- Escalation rotation: `CODEOWNERS`, `docs/operations/on-call.md` or
  `.bearing/company.json` contacts; if absent, `<on-call rotation>`.
- This skill runs forked under `doc-writer`: no shell, no question
  to the user mid-run, edits under `docs/` only. The alert definition
  is found with Grep and Glob; the one question under Alert name is
  returned in the output when `$1` is absent.

## Steps

0. After an incident (`--from-incident <doc>`): read the incident
   timeline and fold what the responders did into the existing runbook
   (commands that worked, a signal that misled, a missing step), keeping
   every section the template has. The runbook is updated each time an
   incident closes, or it drifts from what the team actually does.
1. Resolve the alert as in Inputs. Use its exact name for the file:
   `docs/runbooks/<alert-name>.md` (create the directory).
2. Read the template and gather the service facts.
3. Fill every section. Diagnosis steps carry the exact command or panel
   and what healthy versus unhealthy looks like. Remediation steps are
   ordered by likelihood and each says how to confirm it worked. Rollback
   names the mechanism (revert, flag, migration Down). Escalation names a
   rotation, not a person.
4. If the alert rule is in this repository and lacks `runbook_url`,
   list the annotation to add under Follow-ups (the rule file is
   outside `docs/`; `observability` or the engineer adds it).
5. Set "Last verified". This skill has no shell, so it never runs a
   diagnosis command itself: the line reads `Last verified: not run`.
   It carries a date only when the caller supplied the output of the
   diagnosis commands from a real run (pasted in the request or in a
   file it names); then it reads `Last verified: <date of that run>
   (diagnosis steps <n> of <m> run)` and each step's output is quoted
   under it as the evidence. Writing today's date for a runbook nobody
   ran is a false claim. Print the path with the count of placeholders
   left.

## Output contract

```
## Runbook: docs/runbooks/<alert-name>.md
Alert rule: <file> (runbook_url present | follow-up: add it) | not in this repository
Sections filled: 8 of 8   Placeholders left: N (listed)
Last verified: not run | <date> (diagnosis steps <n> of <m> run, output quoted)
```

## Gotchas

- Commands in a runbook are run at 3 a.m. by someone who did not write
  the service; every one must be copy-pasteable with placeholders in
  angle brackets.
- Never include credentials or hostnames of production databases; point
  at the secret manager and the inventory.
- One alert, one runbook. A runbook that covers three alerts is three
  runbooks.
- A runbook with placeholders is still better than none; the report says
  how many and the on-call reviewer fills them.
- "Last verified" means someone ran the diagnosis steps against the
  service and saw the output. Reading the code is not verification; a
  runbook that says `not run` tells the on-call engineer to trust the
  commands less, which is the truth.
