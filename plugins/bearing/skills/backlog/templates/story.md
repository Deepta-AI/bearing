<!-- Template guidance: docs/product/backlog.md. It opens with the story
     index and the hours roll-up once, then one epic block and one story
     block per epic and story. Engineers, testers, the client and the
     coverage gate read it, so ids are permanent: a removed story stays in
     place marked withdrawn:. The index is the one table a table-to-CSV
     exporter reads for stories; keep its header row and column names.
     Tasks live in docs/product/tasks.md (templates/tasks.md). Every
     comment says what goes there (What), what a strong entry has (Good)
     and an example (Example). Delete each comment when you fill its
     section. -->

# Backlog: <product>

PRD: docs/product/PRD.md   Questions: docs/product/questions.md   Built: <date>

## Story index

<!-- What: one row per story, live or withdrawn, in epic order; the
     tracker import and the CSV exporter read this table.
     Good: every cell is filled: Points is the story's own value (1, 2, 3,
     5, 8, or TBD until estimate sizes it); Depends on is story ids or
     none; the gate fails a live story with no row or a Points value that
     differs from its block.
     Example: "US-00-014 | EP-03 | Match an emailed report to a patient |
     Receptionist | Must | 5 | REQ-014, REQ-015 | US-00-012" -->

| Story | Epic | Title | Persona | Priority | Points | Covers | Depends on |
| --- | --- | --- | --- | --- | --- | --- | --- |
| US-nn-nnn | EP-nn | <verb-first title> | <persona> | Must / Should / Could | TBD | REQ-nnn | none |

## Hours by discipline

<!-- What: the task hours rolled up by discipline, from tasks.md.
     Good: copied from the gate's "tasks:" line verbatim, never summed by
     hand; TBD tasks are counted, not guessed, and estimate fills them.
     Example: "tasks: 41 (29 development, 12 test), hours by discipline:
     backend 88, frontend 64, qa 46; total 198 h, 0 TBD" -->

<the coverage_check "tasks:" line, verbatim>

## EP-nn <epic name, a user goal>

<!-- What: one user goal, the outcome the user has when every story under it
     ships, and the REQ ids its stories cover.
     Good: named for what the user achieves, never for a layer ("API",
     "database" are not epics); the goal line is checkable by walking its
     journey in user-flows.md.
     Example: "EP-03 File lab reports without re-keying. Goal: a receptionist
     files every emailed report against the right patient from one inbox." -->

Goal: <what the user can do when this epic is complete>
Covers: REQ-nnn, REQ-nnn

### US-nn-nnn <story title, verb first>

<!-- What: one story that ships on its own: a user can do something new when
     it lands. The id group is who triggers it (00 end user, 01 admin, 02
     operator, 03 integration).
     Good: "Why it matters" names a business objective id (B1..Bn) from the
     PRD and says how this story moves it; "From the PRD" quotes every REQ
     on the Covers line in the PRD's own words; each criterion has a Then a
     tester can observe and a Covers line; seven criteria at most, and more
     than seven or two personas is two stories. "Not in this story" says
     where each exclusion lives (a story id, a Q-nnn, a PRD non-goal).
     Points is TBD until estimate sizes it; no dates, no owners.
     Example: "US-00-014 Match an emailed report to a patient, merged from
     REQ-014 and REQ-015; Why it matters: B1, every report filed by hand is
     a re-keying error waiting to happen." -->

Epic: EP-nn   Priority: Must | Should | Could   Points: TBD (estimate)
Persona: <name, group nn>   Ticket: <<PREFIX>-<n> or unassigned>
Covers: REQ-nnn, REQ-nnn   Judgement: <story | merged from REQ-a, REQ-b | split from REQ-c>

**Narrative.** As a <persona>, I want <capability>, so that <outcome>.

**Why it matters.** <B-id>: <how this story moves that objective, in one or
two sentences; what stays blocked until it ships>

**From the PRD.**
- REQ-nnn: "<the statement, quoted from the PRD>"
- REQ-nnn: "<the statement, quoted from the PRD>"

**Preconditions.**
- <state that must hold before the story applies>

**Acceptance criteria.**

- AC-US-nn-nnn-1. Given <context>, when <action>, then <observable result>.
  Covers: REQ-nnn
- AC-US-nn-nnn-2. Given <context>, when <action>, then <observable result>.
  Covers: REQ-nnn

**Not in this story.**
- <a precise exclusion a reader might expect here> (<US-nn-nnn has it | Q-nnn | PRD non-goal>)

**Depends on.**
- <US-nn-nnn: what it provides that this story needs, or none>

**Assumptions.**
- <what is taken as true> (<Q-nnn when it rests on a register entry, or inferred:>)

**Tasks.** <US-nn-nnn-D1 to Dn, US-nn-nnn-T1 to Tm> in docs/product/tasks.md
