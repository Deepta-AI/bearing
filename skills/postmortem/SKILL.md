---
name: postmortem
description: 'Writes a blameless postmortem after an incident: impact in numbers, UTC timeline, root cause chain, owned follow-ups, lessons. Use when asked for a "postmortem", "RCA", "incident report" or "write up the outage".'
argument-hint: "<incident title> [path to notes]"
context: fork
agent: doc-writer
allowed-tools: Read, Write, Grep, Glob
---

# postmortem

An incident that is not written up happens again. This skill turns
whatever record exists into a document the next on-call can learn from.

## Inputs

- Notes: `$2` (a file path) or pasted text; if absent, the latest
  `docs/postmortems/*-incident.md` (the live doc `incident` keeps);
  if none, one question: "paste the notes, the chat log or the timeline,
  or point to a file". Nothing: stop with "provide notes, a chat log or a
  timeline".
- Title: `$1`; if absent, the incident doc's title, else the first line
  of the notes.
- Template: `docs/templates/POSTMORTEM.md` when present, else
  `templates/POSTMORTEM.md` in this skill's folder.
- Deploys and changes around the incident: tags under `.git/refs/tags/`
  and `.git/packed-refs`, and any `git log` output the caller pasted for
  the range; otherwise the timeline rests on the notes alone and says so.
- Task ids: the tracker prefix seen in existing docs or branch names in
  `.git/refs/heads/` (`<PREFIX>-<n>`); if unknown, `<TASK>` placeholders.
- This skill runs forked under `doc-writer`: no shell, no question
  to the user mid-run. The one question under Notes is returned in the
  output when nothing was found.

## Steps

1. Read the notes as in Inputs. If there is no timeline, build one from
   the notes and mark every time you inferred with "~".
2. Read the template. File: `docs/postmortems/YYYY-MM-DD-<kebab-title>.md`
   (create the directory).
3. Fill every section. Impact has numbers (users, requests, minutes,
   money) or "unknown, measure: <how>". Root cause is a chain ("A allowed
   B, which under C produced D"), never a person. Follow-ups are actions
   with an owner, a task id placeholder and a due date; a follow-up
   without an owner is deleted, not left. One follow-up is always the
   runbook: confirm the incident doc records it as updated, or add
   "update docs/runbooks/<alert>.md with the response" with an owner.
4. Lessons are beliefs about the system that changed, one line each.
5. Print the output contract.

## Output contract

```
## Postmortem: docs/postmortems/<file>
Source: <notes path | incident doc | pasted>   Timeline entries: N (M inferred)
Root cause: <A> allowed <B>, which under <C> produced <D>
| Action | Owner | Task | Due |
...
Due: within five working days | late by N days
```

## Gotchas

- Blameless is a rule, not a tone. Replace every "X forgot" with the
  condition that let forgetting matter.
- "Add more monitoring" is not a follow-up; "alert when queue depth over
  N for M minutes, runbook Y" is.
- Five working days from the incident; if later, say so at the top.
- Notes with no times at all still produce a postmortem; every timeline
  row carries "~" and the Impact section says duration is unknown.
