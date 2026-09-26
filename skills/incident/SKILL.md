---
name: incident
description: 'Runs a live incident as scribe: severity, UTC timeline, roles, runbook steps for a person, comms, postmortem hand-off; never remediates. Use when "we have an outage", "declare an incident" or "the alert is firing".'
argument-hint: "declare <alert or title> [--sev 1|2|3|4] | update \"<note>\" | comms | resolve"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(ls:*), Bash(mkdir:*), Bash(date -u:*), Bash(git log:*), Bash(git tag -l:*)
---

# incident

During an incident the agent is the scribe with a clipboard, not a
pair of hands on production. Every line it writes is timestamped, every
step it suggests names the runbook it came from, and every remediation
is done by a person.

## Inputs

- Mode and title: `$ARGUMENTS`; if absent, one question: "declare,
  update, comms or resolve, and which incident?". Nothing: stop with
  "provide the mode and the alert or title".
- Severity reference and templates: `references/severity.md`,
  `templates/incident.md`, `templates/comms.md`, all in this skill's
  folder; never a repository copy.
- Incident doc: looks in `docs/postmortems/*-incident.md` for update,
  comms and resolve; if absent, asks which file, or declares first.
- Runbook: looks in `docs/runbooks/<alert name>.md`; if absent, the
  nearest runbook for the service by grep; if none, the diagnosis is
  taken from the alert's own description and the doc says "no runbook";
  `runbook` writes one after the incident.
- Flags: looks in `docs/operations/flags.md`; if absent, flag names
  grepped from the code; if none, the flag step is marked `n/a`.
- Last deploy: the latest tag or `git log -1`; not a git repository,
  "last deploy: unknown, ask the person".

## Steps

1. `declare <alert or title>`: read `references/severity.md` and set
   the severity from user impact, not from the alert's label. Ask one
   question if the impact is unknown; otherwise pick the higher of the
   two candidates and say why. Sev 1 and 2 page the on-call lead now.
2. Open `docs/postmortems/<YYYY-MM-DD>-<kebab-title>-incident.md` from
   `templates/incident.md` (create the directory). First timeline entry:
   `date -u +%H:%MZ`, "declared, sev N, by <name>". Roles: incident lead
   (decides), comms (talks to stakeholders, owns the status page), scribe
   (this doc). One person may hold two roles; the lead never holds comms
   in sev 1.
3. Runbook lookup as in Inputs. With a runbook, print the diagnosis
   section verbatim, then the first remediation step with its confirm
   line. Without one, print the alert's condition and the generic first
   check (recent deploys, error rate, saturation). The person runs it and
   reports back.
4. Mitigation checklist, in this order, stop at the first that clears
   the impact: rollback the last deploy (the release tag from Inputs),
   turn a flag off (the kill switch if one exists), scale out, fail over,
   shed load. Each is a suggestion with the exact command from the
   runbook when there is one; the agent runs none of them.
5. `update "<note>"`: append a timeline line with the UTC time. Notes
   that change the picture (impact widened, mitigation applied, root
   cause hypothesis) also update the doc's status block.
6. `comms`: fill `templates/comms.md` for the current severity: the
   internal stakeholder message, the status page entry, the customer
   note when sev 1 or 2. Cadence: sev 1 every 30 minutes, sev 2 every
   hour, sev 3 at declare and resolve. The comms role posts them; the
   agent writes them into the doc under Comms log.
7. `resolve`: final timeline entry, impact numbers if known (users,
   requests, minutes) or "unknown, measure: <how>", status `resolved`,
   the follow-up placeholder table, and the line `next: postmortem
   "<title>" docs/postmortems/<file>` within five working days. Before
   `resolved` is written, the runbook for the alert that fired is updated
   with what the responders actually did: the commands that worked, the
   signal that misled, the step that was missing. Name it in the doc as
   `runbook: docs/runbooks/<alert>.md updated | none existed, runbook
   <alert>`; a resolve that leaves the runbook as it was is not done.
8. Print the contract after every mode.

## Output contract

```
## Incident: <title> (sev N, <status>)
Doc: docs/postmortems/<file>
Roles: lead <name>, comms <name>, scribe <name>
Runbook: docs/runbooks/<alert>.md | nearest: <file> | none (write one after: runbook)
Next step for the person: <runbook step, verbatim, with its confirm line>
Timeline entries: N; comms sent: N (last <HH:MM>Z, next due <HH:MM>Z)
Mitigation tried: <list> | none yet
```

## Gotchas

- The agent never runs a remediation, a rollback, a scale command or a
  flag flip. It prints the step; the person types it and reports the
  result.
- Timestamps are UTC with a `Z`; the status page and postmortem use
  the same clock. Local time appears nowhere in the doc.
- "Customers cannot pay" is sev 1 even when the alert says warning.
  Severity follows impact; it can go up during the incident, and it
  goes down only at resolve.
- No blame in the timeline. "Deploy 1.4.2 rolled out" not "X deployed a
  broken build".
- A comms message never guesses at a cause. "We are investigating
  elevated errors" until the lead confirms.
- Resolve means the impact stopped, not that the cause is known. The
  cause is the postmortem's job.
