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
  register is created here with the columns listed in step 3 (the same
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
   `withdrawn:`, and the `B` ids of its objectives. No PRD: take the source
   under Inputs, split it into one testable statement per line, number
   them `REQ-001` upward, and write them as a "Statements (inline, from
   <source>)" table at the top of `docs/product/coverage.md` so every id
   resolves; say the fuller PRD comes from `prd`. Read the existing
   backlog, tasks and register; keep every epic, story, AC, task and
   question id in whatever scheme they use; never renumber.
   Then read the code, config and tests the statements land on. A PRD is
   written against a system that already exists, and the traps live in
   the gap between the two. For each rule a statement sets (a limit, a
   threshold, a required field, who may act), find where the code holds
   it and note one of: enforced as stated; held with another value (name
   the constant, the test that pins it and any policy it cites); checked
   nowhere below the screen (a rule the service does not refuse is not
   enforced: an API call or an import skips the form); or contradicted
   by a rule the code enforces that the statement breaks (a permission, a
   state transition). The first is a note; the second and fourth are
   Q-nnn contradictions; the third becomes a criterion that the service
   itself refuses, with the file and function named. Also read any notes,
   minutes or ADRs beside the PRD: a decision recorded there and not yet
   in the PRD is raised, never cited under a REQ id.
2. Judge each REQ and record the judgement and one sentence of why (both
   go into coverage.md):
   - story: a user can do something new when it lands; it seeds a story;
   - criterion-of: it qualifies another statement (a limit, a message, a
     timing); it becomes an AC of that story;
   - platform-detail-of: the same capability on web, iOS, Android; one
     story, the platforms named in its AC or tasks;
   - duplicate-of: same outcome as another REQ; merge, cite both ids;
   - split: it hides two capabilities; two stories, both citing the REQ;
   - non-functional: a quality (security, performance, accessibility)
     carried as AC by every story it constrains;
   - out-of-scope: the input or a decision puts it out; it needs a Q-nnn
     whose Decision says so, cited in the Why cell.
3. Open points. Every ambiguity, gap or contradiction met while judging,
   and every decision the PRD leaves open that a story had to take (a
   limit, a timing, a routing rule, what happens at the edge), becomes a
   `Q-nnn` row in `docs/product/questions.md` (or in the existing
   backlog's own question table, continuing its numbering): Kind
   (open-question, gap, contradiction), Where, Basis (stated, inferred,
   convention, assumption), the readings available, the Decision taken
   so the work is not blocked, Why, Affects and Status. Open assumptions
   come first and are listed under "Needs your confirmation". Replace
   every Affects cell, including `prd`'s REQ ids, with the story ids
   the decision changes; it is never empty.
4. Group stories into epics `EP-nn` by user goal, never by layer ("API",
   "database" are not epics). New backlog: assign the persona group from
   the PRD's personas (00 end users, 01 admins, 02 operators, 03
   integrations) and the story id is `US-<group>-<nnn>`, sequential within
   the group, chosen by who triggers the behaviour. Existing backlog: a
   new story takes the backlog's own scheme, the next number after the
   highest ever used (withdrawn ids count, never reused); no second id
   scheme is added beside it.
5. New backlog: write `docs/product/backlog.md` from `templates/story.md`
   (an existing one is edited in its own shape, below): the story
   index, then per story: narrative; "Why it matters" citing a `B` id and
   how the story moves it; "From the PRD" quoting every covered REQ in the
   PRD's words; preconditions; at most seven acceptance criteria in
   Given/When/Then with ids `AC-US-nn-nnn-k` and a `Covers: REQ-nnn` line
   each; "Not in this story", each exclusion naming where it lives;
   "Depends on" with the reason; assumptions citing their Q-nnn; Points
   (`TBD` until `estimate`); priority (Must, Should, Could). Every REQ
   the story covers appears in at least one AC.
6. Full pack only (see Scope). Write `docs/product/tasks.md` from `templates/tasks.md`: per story the
   development tasks `US-nn-nnn-D1` upward and the test tasks
   `US-nn-nnn-T1` upward, each with discipline (backend, frontend, mobile,
   qa, devops; a test task is qa), Estimate (hours from `estimate`,
   else `TBD`), Depends on, Done when and the AC ids it verifies. Every
   story gets both kinds and every AC is verified by a test task. A task
   over 8 hours is two tasks.
7. Write `docs/product/coverage.md` from `templates/coverage.md`: one row
   per REQ with judgement, why and covering stories; gaps are REQ rows with
   no story. Also list orphan stories (no REQ) marked `inferred:` for the
   user to accept or drop. Write the files anyway so a gap is visible.
8. Full pack only. Write `docs/product/user-flows.md` from `templates/user-flows.md`: at
   least one journey per epic with persona, platforms, trigger, what holds
   before it starts, the step table (Screen, The user, The system, Story),
   alternate paths, failures with the story that handles each, and the end
   state. A failure no story handles is a `gap:` for the user.
9. Run the gate:
   `python3 "${CLAUDE_PLUGIN_ROOT}/skills/backlog/scripts/coverage_check.py"`
   (add `--prd <path>` when `$1` named another PRD). It detects the id
   scheme from the committed backlog (`--story-id REGEX` overrides) and
   checks tasks.md and questions.md when they exist. It computes coverage
   from the AC `Covers:` lines (an adopted backlog may trace at story
   level, and a definition of done may carry a non-functional REQ) and
   fails on a story id at HEAD that is gone or renumbered, a withdrawn id
   made live, a live story covering a withdrawn REQ with no question
   raised, a withdrawn story that code or tests outside docs/ still name
   with no question raised, an uncovered REQ, an unknown or
   withdrawn REQ in a Covers line, a story over seven AC, a story without
   its objective, quotes or exclusions, an index row missing or out of
   step, a matrix row without its judgement or why, an out-of-scope REQ
   with no Q-nnn, an epic with no journey, a task table that breaks the
   rules in step 6, and a register row with an empty Affects or an
   assumption outside "Needs your confirmation". The house-format blocks
   (objective, quotes, exclusions, Points) are checked on a US-nn-nnn
   backlog only. Fix what it reports and rerun until it exits 0. Copy its
   "tasks:" line into the backlog's "Hours by discipline" (full pack) and
   its counts line into coverage.md.
10. Full pack only. Write `docs/product/IMPORT.md` from `templates/import.md`: the files
    and how each imports (`tracker-sync sync` for epics and stories, CSV
    for tasks), the open assumptions to confirm before committing, what is
    still open, and what is out of scope. Print the gate's lines unchanged.
    Never write a count the script did not print.

## Updating an existing backlog

A backlog people are tracking is edited, not rebuilt. Find what changed
and touch only the stories a change lands on.

- Diff the statements themselves, not the change log. Compare each REQ's
  current wording with the criteria that cover it (and the previous PRD
  in git history when there is one). Change logs omit edits, and the
  omitted ones are small: a boundary made inclusive, "days" becoming
  "working days", "each" becoming "any", a unit. A boundary change against a Done story is new work like
  any other.
- A new statement changes existing stories it never names. For each
  one, ask who acts, who is notified, who may decide and when, and check
  those against every Done and In progress story and the code behind
  them: a new actor who must approve breaks a shipped "only the owner
  may approve" check, and a new recipient changes a notification story
  under way. Name each such story and
  the code rule it breaks.
- Where a new statement overlaps an existing story, state the difference
  in one line (who acts, on what trigger, for how long) or merge them.

- Shape: keep the file's headings, id scheme, AC numbering, status column
  and question table. New stories are written in that same shape. Stories
  no change touches keep their text; do not upgrade them to the house
  template.
- Each changed statement, by the status of the story it lands on:
  - To do: edit the story in place and say so in the report.
  - In progress: do not change the scope mid-sprint silently. Leave the
    criteria, add a note naming the change, and raise a Q-nnn with the
    readings (finish as planned and follow up, change it in this sprint,
    stop it).
  - Done: never rewrite a shipped criterion as if the new value had been
    delivered. Add a new story that changes it, citing the Done story, and
    name the code, config and tests that still hold the old value.
- A withdrawn statement: a To do story is marked `withdrawn:` in place
  with the reason. An In progress story keeps its status: someone is
  building it and the tracker mirrors it, so withdrawal is proposed in a
  Q-nnn with the readings and the team changes the status. Search code and tests for the
  story id (the gate lists them): each hit is work someone must keep,
  repoint or remove, so it goes in that Q-nnn. Never edit code or tests
  from this skill.
- A new statement that restates an existing capability is folded into that
  story (its Covers line), not given a story of its own.
- A new statement that conflicts with an accepted ADR or the PRD's own
  non-goals is not written as ready work: the story is blocked on its
  Q-nnn, whatever reading you assume.
- New stories are not placed in the running sprint; propose, do not
  schedule.
- The report lists the stories added, changed, reopened and withdrawn, and
  copies the gate's `ids:` line, whose "changed since HEAD" list must
  match that summary.

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
