---
name: adr
description: 'Writes an architecture decision record in docs/adr with context, options and consequences, Proposed until someone accepts it. Use when asked to "write an ADR", "record this decision" or "why did we pick X".'
argument-hint: "<title>"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(ls:*)
---

# adr

Records one decision so the next person knows why the code is the way it
is.

## Inputs

- Title: `$1`; if absent, from the request.
- Folder: `docs/adr/`; if absent, created.
- Number: the highest existing number plus one.

## Steps

1. Read the existing ADRs; if one already covers the question, supersede
   it rather than edit it.
2. Write `docs/adr/NNNN-<slug>.md` with Status Proposed, Context, Options,
   Decision and Consequences.
3. Link the superseded ADR both ways when there is one.

## Output contract

```
ADR: docs/adr/NNNN-<slug>.md (Proposed)
Supersedes: ADR-MMMM | none
```

## Gotchas

- An accepted ADR is never edited to say something new; supersede it.
- Status is Proposed until a person accepts it.
