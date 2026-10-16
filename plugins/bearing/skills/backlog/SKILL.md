---
name: backlog
description: 'Turns PRD requirements into a backlog of epics and Given-When-Then user stories with a coverage matrix, combining statements. Use when asked to "write the user stories", "build the backlog" or "break down the PRD".'
argument-hint: "[path to the PRD, default docs/product/PRD.md]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(ls:*), Bash(mkdir:*), Bash(python3 *skills/backlog/scripts/coverage_check.py*)
---

# backlog

A PRD's numbered lines are statements of intent, not stories. One story per
line produces a backlog of fragments nobody can ship or test. This skill
judges every statement first, then writes stories that ship on their own,
breaks each into tasks a sprint can plan, and keeps every `REQ-nnn`
traceable to the stories, criteria and tests that cover it.

Not this: pm-skills `user-stories` writes stories from a feature idea;
this judges and combines a PRD's numbered REQ statements on this
standard and proves coverage with a gate.

## Inputs

- Requirement statements: looks in `$1` or `docs/product/PRD.md`; if
  absent, accepts any pasted brief, a file path, an existing tracker
  export or the README's feature list, and numbers the statements itself
  (`REQ-nnn`) before proceeding; `prd` produces the fuller PRD. Zero
  statements after one question stops the skill: "provide a PRD, a brief
  or a file path".
- Business objectives: the PRD's objectives table (`B1` upward); if
  absent, each story's "Why it matters" names the outcome in words and
  the report says "0 objectives".
- Open questions: looks in `docs/product/questions.md`; if absent, the
  register is created here with the columns listed in step 3 Detail (the same
  shape `prd` writes).
- Existing backlog: looks in `docs/product/backlog.md` (and
  `docs/product/tasks.md`); if present, this is an update (see "Updating
  an existing backlog") and the backlog's own id scheme, shape and status
  column are kept; if absent, numbering starts fresh in the house scheme.
- Scope: a request for stories ("write the stories", "break the PRD into
  stories") gets the backlog, the coverage matrix and, when anything is
  open, the question register. Tasks, user flows and IMPORT.md are added
  when the request asks for tasks, estimates, flows or a tracker import,
  or when those files already exist. Say in the report which you wrote.
- Personas: looks in the PRD's personas section; if absent, derived from
  the roles the statements name, marked `inferred:`, group 00 by default.
- Estimates: story points and task hours from `estimate`; if it has
  not run, both read `TBD`.
- Templates: `templates/story.md`, `templates/tasks.md`,
  `templates/coverage.md`, `templates/user-flows.md` and
  `templates/import.md` in this skill; no repository copy is needed.
- Gate: `scripts/coverage_check.py` in this skill, Python 3 only, run from
  the repository root; it reads the files, never the model's summary.

## Steps

1. Read the PRD (`$1` or `docs/product/PRD.md`) and collect every id
   matching `REQ-[0-9]{3}` from the statements table, skipping rows marked
   `withdrawn:`, and the `B` ids of its objectives; never renumber an
   existing id. Detail: references/read-and-judge.md
2. Judge each REQ and record the judgement and one sentence of why (both
   go into coverage.md): story, criterion-of, platform-detail-of,
   duplicate-of, split, non-functional or out-of-scope (needs a Q-nnn).
   Detail: references/read-and-judge.md
3. Open points. Every ambiguity, gap or contradiction met while judging
   becomes a `Q-nnn` row in `docs/product/questions.md` (columns in the
   reference); Affects is never empty. Detail: references/open-points-and-epics.md
4. Group stories into epics `EP-nn` by user goal, never by layer. Story
   ids: a new backlog uses `US-<group>-<nnn>`; an existing one keeps its
   own scheme and never reuses a number. Detail: references/open-points-and-epics.md
5. New backlog: write `docs/product/backlog.md` from `templates/story.md`
   (an existing one is edited in its own shape, below): at most seven
   acceptance criteria per story, each with a `Covers: REQ-nnn` line.
   Detail: references/write-the-pack.md
6. Full pack only (see Scope). Write `docs/product/tasks.md` from
   `templates/tasks.md`: development and test tasks per story; every AC
   is verified by a test task. A task over 8 hours is two tasks. Detail:
   references/write-the-pack.md
7. Write `docs/product/coverage.md` from `templates/coverage.md`: one row
   per REQ with judgement, why and covering stories; gaps are REQ rows with
   no story. Detail: references/write-the-pack.md
8. Full pack only. Write `docs/product/user-flows.md` from
   `templates/user-flows.md`: at least one journey per epic. A failure no
   story handles is a `gap:` for the user. Detail: references/write-the-pack.md
9. Run the gate:
   `python3 "${CLAUDE_PLUGIN_ROOT}/skills/backlog/scripts/coverage_check.py"`
   (add `--prd <path>` when `$1` named another PRD). It detects the id
   scheme from the committed backlog (`--story-id REGEX` overrides) and
   checks tasks.md and questions.md when they exist. Fix what it reports
   and rerun until it exits 0. Copy its "tasks:" line into the backlog's
   "Hours by discipline" (full pack) and its counts line into coverage.md.
   Detail: references/gate.md
10. Full pack only. Write `docs/product/IMPORT.md` from
    `templates/import.md`. Print the gate's lines unchanged. Never write a
    count the script did not print. Detail: references/write-the-pack.md

## Updating an existing backlog

A backlog people are tracking is edited, not rebuilt. Find what changed
and touch only the stories a change lands on. Never rewrite a Done
story's shipped criterion, never change an In progress story's scope
silently, never edit code or tests from this skill, and propose new
stories without scheduling them. Detail: references/updating-an-existing-backlog.md

## Output contract

```
## Backlog from <PRD path>: <N> REQ statements read, <B> objectives
Judged: N (story S, criterion-of C, platform-detail-of V, duplicate-of D,
        split X, non-functional F, out-of-scope O)
Epics: E   Stories: U   Acceptance criteria: A   Flows: F or not written
<the gate's "ids:" line, verbatim>
<the gate's "withdrawn-refs:" line, verbatim>
<the gate's "tasks:" line, verbatim>
<the gate's "questions:" line, verbatim>
<the gate's "stories-coverage:" line, verbatim>
Written: <the files actually written or edited>
Changed (update only): added <ids>; changed <ids>; reopened by <ids>;
         withdrawn <ids>
Verdict: covered | not covered (G REQ without a story, P problems)
```

## Gotchas

- The verdict is the script's, not a reading of the matrix. A matrix row
  that says "covered" while no AC names the REQ is exactly the gap the
  script exists to catch.
- Combining statements never drops an id. A story built from four REQ
  lines lists all four under Covers and quotes all four; the gate proves it.
- An AC that restates the narrative ("the feature works") is not a
  criterion. Each AC has a concrete Then a tester can observe.
- A story with more than seven AC or two personas is two stories.
- A decision that rests on an assumption is not settled. It goes under
  "Needs your confirmation" and in IMPORT.md's "Before you commit", so the
  client reads it before the sprint does.
- "Not in this story" is for what a reader would expect here and not
  find; each line says which story, question or non-goal has it.
- Ids are permanent once written, in the scheme the backlog already uses.
  Adding a house `US-nn-nnn` id beside a tracker key, or rewriting the
  file in the house template, is a renumbering however the old key is
  kept; the gate fails it. A story removed later is marked `withdrawn:`
  in place so tests and commits that name it still resolve.
- A backlog under way has history: a Done story's criteria describe what
  shipped. The PRD moving on is new work, not an edit to history.
- A request that names a sprint wants an order, not only a list. End the
  report with a proposed first cut: enablers before the stories that
  need them, and no story whose criteria rest on an open contradiction
  offered as a commitment (say what unblocks it). Proposed, never
  scheduled.
- Do not size stories or tasks here; `estimate` fills Points and
  hours, and the tracker assigns owners and dates.
