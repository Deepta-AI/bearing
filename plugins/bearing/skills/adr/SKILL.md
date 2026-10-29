---
name: adr
description: 'Records a decision already made as a numbered ADR: context, options, outcome. Use when asked to "write an ADR" or "record this decision".'
argument-hint: "<title in the imperative, e.g. Use ClickHouse for events>"
allowed-tools: Read, Write, Grep, Glob, Bash(ls:*), Bash(git log:*), Bash(git branch:*), AskUserQuestion
---

# adr

An ADR records one decision future readers will ask "why" about: the
facts that forced it, the options weighed, the choice, its cost, how
hard it is to undo and what it commits the team to. It runs in any
repository; the template and the numbering come from the repository
when they exist and from this skill otherwise.

Not this: choosing between options is `tech-decision`; this skill records a
decision already made (and `tech-decision` calls it, or writes the same
shape from this skill's template).

## Inputs

- Title: looks in `$ARGUMENTS`; if absent, asks one question for the
  decision in the imperative ("Use X for Y").
- ADR convention: an `.adr-dir` file (adr-tools), the ADR location
  named in `CLAUDE.md`, `AGENTS.md` or the README, then existing ADR
  files under `docs/adr/`, `docs/decisions/`, `docs/architecture/decisions/`,
  `doc/adr/`, `doc/architecture/decisions/`, `adr/`, `decisions/` or
  `architecture/decisions/` (files matching `NNNN-*`, `ADR-NNN-*` or
  `adr-NNN-*`, in `.md`, `.rst` or `.adoc`). The directory, the
  numbering width and prefix, the filename case, the extension and the
  section headings found there are the convention. None found:
  `docs/adr/`, `NNNN-<kebab-title>.md`, this skill's headings.
- Template: looks for a template in the ADR directory (`0000-template.md`,
  `template.md`, `adr-template.md`); if absent, the headings of the
  newest existing ADR; if none, this skill's `templates/adr.md` without
  installing a repository copy.
- Existing ADRs: every ADR file in the repository, in any directory or
  scheme, gives the next number (step 2); the ones in the chosen
  directory give a decision this one supersedes. If no ADR directory
  exists, creates `docs/adr/` and starts at `0001`.
- Decisions index: `docs/architecture/decisions.md`; if absent, created
  from `${CLAUDE_PLUGIN_ROOT}/skills/high-level-design/templates/architecture-decisions.md`
  with this ADR as its first row. Its rows use each ADR's id as the ADR
  files write it (`0004`, `ADR-015`), never a numbering of their own.
- Area and standard stack: the keys and defaults in
  `${CLAUDE_PLUGIN_ROOT}/skills/tech-decision/references/catalogue.md`; if
  unreadable, Area is a short noun and no technology is marked outside
  the standard stack. The catalogue gives Area and the "outside the
  standard stack" marks only; it is never a context fact or a reason.
- Context facts: the code (routes, schemas, migrations, manifests), the
  README and `git log` for what is in use today; facts given in the
  request are quoted with "from the request". Reasons, dates and people
  the request and repository do not give are written "(to be
  confirmed)", never supplied from general knowledge or the catalogue.
- Options: the ones the user or the calling skill names; if only one is
  known, asks one question for the alternative that was considered, and
  writes "no alternative was considered" as an option when the answer is
  none.
- Task id: from the branch name; if the branch carries none, `Task: none`.

## Steps

1. Convention: search the locations in Inputs and print "ADR
   convention: <dir>, <pattern>, N existing (from <.adr-dir | CLAUDE.md
   | existing files | default>)". Two directories that both hold ADRs,
   or two numbering schemes in one directory, is a conflict: name both
   and ask one question with AskUserQuestion, one option per scheme, which to follow
   (as `${CLAUDE_PLUGIN_ROOT}/references/console.md` says); never add a third scheme.
2. Next number: the highest number among every ADR in the repository,
   in any directory or scheme, plus one, so no two ADRs share a number
   (`0002` and `ADR-003` make the next one 4); written in the chosen
   directory's width and prefix (a template file does not count; no ADR
   anywhere means `0001`). File: `<dir>/<prefix><number>-<title in its case>.<ext>`,
   default `docs/adr/NNNN-<kebab-title>.md`.
3. Read the template (the repository copy when present, else
   `templates/adr.md`) and any existing ADR the decision touches; if it
   supersedes one, say which. When the new ADR is Accepted, change only
   the old one's status line to `Superseded by <new id>` now, in its own
   status format; its decision text stays byte for byte. When Proposed,
   leave the old one untouched.
4. Fill every section, under the convention's headings when they differ
   from the template's (map context, options, decision and consequences
   onto them; add a missing one rather than drop it). Area is the
   catalogue key. Reversibility is cheap, awkward or irreversible, then
   what reversing costs. Context is facts and constraints with numbers,
   no options. What else was considered is a table: the chosen option
   first, then at least one alternative, each with Why not (cost and
   risk) and Would suit (the fact that would make it right). Decision is
   one sentence starting "We will", then the reasons in order of weight,
   each from the request or the repository; with none given, "Reasons:
   to be confirmed".
   Consequences include what becomes harder and the trigger for
   revisiting. Commits us to lists every product, service and library by
   name, marking any that is not a catalogue default "(outside the
   standard stack)".
5. Status Accepted when the request says the decision is accepted,
   agreed or made (at a review, a meeting, by a named person); write it
   Accepted with that date, not "Proposed, awaiting confirmation".
   Otherwise Proposed. Task id from the branch.
6. Index: add a row (id as the ADR files write it, title, area,
   status, reversibility) to `docs/architecture/decisions.md`, and set
   the superseded ADR's row to "Superseded by <new id>" when the new one
   is Accepted. No other file or directory is created. Print the output
   contract. No em dashes.

## Output contract

```
## ADR: <dir>/<file>   (convention: <from .adr-dir | CLAUDE.md | existing files | default>)
Status: Proposed | Accepted   Supersedes: none | ADR-nnnn   Task: <ID> | none
Area: <key>   Reversibility: cheap | awkward | irreversible
Options: N (rejected: N-1 | none considered)
Commits us to: K technologies (outside the standard stack: M)
Decision: We will ...
Index: docs/architecture/decisions.md (row added | row updated | created)
```

## Gotchas

- An ADR without a rejected option is a memo. Ask for the alternative
  once with AskUserQuestion (as `${CLAUDE_PLUGIN_ROOT}/references/console.md` says), options "name it" (the answer comes as free text via Other) and "none considered"; record "none considered" if that is the answer, so the reader
  knows the choice was not weighed.
- A rejected option with an empty Would suit is padding: if no fact
  would ever make it right, nobody seriously weighed it.
- "Cheap to reverse" for a store, a wire format or an identity provider
  is almost always wrong; say what moving off it takes.
- Never edit an Accepted ADR's decision; write a new one that supersedes
  it.
- Keep it under 120 lines; link the HLD for detail.
- Writing `docs/adr/0001-*.md` into a repository whose decisions live in
  `docs/decisions/ADR-014-*.md` starts a second history nobody reads.
  Detect the convention first; the default is for empty repositories.
