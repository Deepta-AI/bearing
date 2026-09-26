# Incident: <title>

<!-- Template guidance: every section below carries a comment saying what goes
     there (What), what a strong entry has (Good) and a one-line example
     (Example). Delete each comment when you fill its section. This is the
     live incident doc, kept by the scribe while the incident runs and read
     by the lead, the comms role and later postmortem. Every time is UTC
     with a Z; local time appears nowhere. No blame anywhere in the doc. The
     agent writes suggestions and records results; a person runs every
     remediation. -->

| Field | Value |
| --- | --- |
| Status | investigating / identified / mitigating / monitoring / resolved |
| Severity | sev <N> (`references/severity.md` in incident) |
| Declared | <YYYY-MM-DD HH:MM>Z by <name> |
| Resolved | <YYYY-MM-DD HH:MM>Z |
| Incident lead | <name> |
| Comms | <name> |
| Scribe | <name> |
| Alert | <alert name> (runbook: `docs/runbooks/<alert>.md`) |
| Services | <service list> |
| Postmortem | pending, due <date> (`postmortem`) |

## Current picture

<!-- What: one paragraph, rewritten at every update: what users see, since
     when, what is known, what is being tried.
     Good: no cause until the lead confirms it; a hypothesis is labelled as
     one. When the picture changes (impact widened, mitigation applied),
     update the Status and Severity rows too; severity goes up during the
     incident and comes down only at resolve.
     Example: "Since 14:14Z about 1 in 5 checkout payments fail with a 502.
     Hypothesis: release 4.2.1 (deployed 14:02Z). Rollback to 4.2.0 started
     14:41Z." -->

## Impact

<!-- What: users affected, requests failed, duration and money, each with
     where the number came from.
     Good: a number with a source, or "unknown, measure: <how>"; never a
     guess written as a figure.
     Example: "| Requests failed | 6,480 | API dashboard, 5xx panel, 14:14Z to 14:52Z |" -->

| Measure | Value | Source |
| --- | --- | --- |
| Users affected | <N or unknown, measure: how> | |
| Requests failed | | dashboard panel |
| Duration | | timeline |
| Money | | |

## Timeline (UTC)

<!-- What: every entry is a fact with a time: an alert, an observation, an
     action taken, a decision, a message sent. Inferred times carry a `~`.
     Good: the first row is the declaration with its severity; entries come
     from `date -u +%H:%MZ` at the moment of writing; systems and releases,
     not people's mistakes ("release 4.2.1 rolled out", not "X deployed a
     broken build").
     Example: "| 14:41Z | rollback to 4.2.0 started (Remediation 1 in the runbook) | incident lead |" -->

| Time | Entry | Role |
| --- | --- | --- |
| HH:MMZ | declared, sev N | incident lead |
| HH:MMZ | | |

## Mitigation checklist

<!-- What: the standard mitigations in order; stop at the first that clears
     the impact.
     Good: each row names the exact target (the release tag, the flag, the
     replica counts) and the command from the runbook when there is one; a
     step that does not apply reads "n/a"; the result is what the person
     observed after running it.
     Example: "| Rollback last deploy (4.2.1 to 4.2.0) | 14:41Z | 5xx back under 0.1 percent by 14:52Z |" -->

| Step | Tried at | Result |
| --- | --- | --- |
| Rollback last deploy (<tag>) | | |
| Flag off (<flag or kill switch>) | | |
| Scale out (<what, from N to M>) | | |
| Fail over (<from, to>) | | |
| Shed load (<what was rate limited>) | | |

## Runbook steps taken

<!-- What: each runbook step a person ran, with who ran it and what came
     back.
     Good: names the runbook and step number verbatim; with no runbook, say
     "no runbook" and record the generic first checks (recent deploys, error
     rate, saturation). These rows are what the runbook is updated from at
     resolve.
     Example row: | 14:22Z | ApiErrorRateHigh, Diagnosis 2 (pool panel) | Priya | pool at 100 percent since 14:10Z | -->

| Time | Runbook step | Command run by | Outcome |
| --- | --- | --- | --- |

## Comms log

<!-- What: every message sent, filled from templates/comms.md, one row
     each.
     Good: audience and channel named; the cadence for the severity is kept
     (sev 1 every 30 minutes, sev 2 hourly, sev 3 at declare and resolve);
     a late update is logged as late.
     Example row: | 14:30Z | status page | statuspage.io | investigating: checkout degraded, next update 15:00Z | -->

| Time | Audience | Channel | Message (or link) |
| --- | --- | --- | --- |

## Follow-ups (filled at resolve, owned in the postmortem)

<!-- What: actions noted during the incident, carried into postmortem.
     Good: each has an owner and a due date; one row is always the runbook,
     written as "runbook: docs/runbooks/<alert>.md updated" or "none
     existed, runbook <alert>"; resolve is not done until it is there.
     Example row: | Update docs/runbooks/ApiErrorRateHigh.md with the pool check | payments team | PAY-413 | 2026-09-19 | -->

| Action | Owner | Task id | Due |
| --- | --- | --- | --- |
