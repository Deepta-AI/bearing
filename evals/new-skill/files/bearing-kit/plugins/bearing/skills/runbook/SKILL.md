---
name: runbook
description: 'Writes an operational runbook for one service from its code and config: start, stop, health, alerts and recovery steps. Use when asked to "write a runbook", "how do we operate this" or "on-call notes".'
allowed-tools: Read, Write, Edit, Grep, Glob
---

# runbook

A runbook is read at 3 a.m.; every step is a command or a check.

## Inputs

- Service: the repository root; if it holds several, the one named in the
  request.
- Alerts: alert rule files in the repository; if none, the runbook says
  so.

## Steps

1. Read how the service starts, what it depends on and what it exposes.
2. Write `docs/runbook.md`: start, stop, health, each alert with its
   recovery steps.

## Output contract

```
Runbook: docs/runbook.md (N alerts covered, M without a rule file)
```

## Gotchas

- A recovery step that nobody has run is marked untested.
