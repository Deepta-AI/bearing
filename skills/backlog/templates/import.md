# Importing the backlog: <product>

<!-- Template guidance: docs/product/IMPORT.md, the checklist for whoever
     loads this backlog into the tracker: what each file is, how it
     imports, what to confirm before committing to the plan, what is still
     open and what is deliberately out. backlog writes it last, from
     the files it just wrote. Every comment says what goes there (What),
     what a strong entry has (Good) and an example (Example). Delete each
     comment when you fill its section. -->

<E> epics, <U> stories, <T> tasks, from <N> statements in the PRD.
Gate: <the coverage_check "stories-coverage:" line, verbatim>

## The files

<!-- What: one row per file in docs/product/, what it holds and how it
     reaches the tracker.
     Good: every file written this run is listed; the "How it imports"
     cell is an action (tracker-sync sync, a CSV import, read only), never
     "as needed".
     Example: "tasks.md | development and test tasks, one table, hours by
     discipline | CSV import from the exported tasks table, each row
     parented to its story key" -->

| File | What it holds | How it imports |
| --- | --- | --- |
| PRD.md | the normalised requirements, REQ-nnn | attach to the project as the source document |
| backlog.md | story index, epics and stories with criteria | tracker-sync sync (epics, then stories; writes Ticket: back) |
| tasks.md | development and test tasks with hours | CSV import of the exported table, parent = story key |
| coverage.md | what became of every REQ, and why | read only |
| questions.md | open points, the decision taken, what it rests on | read only; confirm with the client |
| user-flows.md | journeys with alternate and failure paths | read only; the design stage works from it |

## Steps

<!-- What: the numbered actions to load the backlog, in order.
     Good: each step is one action with the command or menu path; the
     hierarchy (epic, story, task) is set by the sync or named per parent
     when a CSV importer cannot carry it; owners and sprints are left to
     the team.
     Example: "3. Run tracker-sync sync; it creates 4 epics and 12 stories
     and writes each Ticket: key into backlog.md. Commit that change." -->

1. Commit docs/product/ so the ids and the Ticket: lines are versioned.
2. Run `tracker-sync sync`: epics first, then stories with their epic as parent; each key is written back as `Ticket:`.
3. Import the tasks from the exported tasks table, parent = the story's Ticket key (or `brg-tracker create --type task --parent <story key>` per row).
4. Assign owners and sprints in the tracker; nothing here guesses at either.

## Before you commit

<!-- What: the open assumptions from questions.md the plan rests on, each
     with what was assumed and the stories that change if it is wrong.
     Good: the same ids as questions.md's "Needs your confirmation", in the
     same order; a reader confirms or corrects each one before the sprint.
     Example: "- Q-004 Which lab formats are accepted? Assumed: PDF only.
     Changes US-00-014, US-00-016 if wrong." -->

- Q-nnn <question>. Assumed: <decision>. Changes <US ids> if wrong.

## Still open

<!-- What: register entries that are open but not assumptions (stated,
     inferred or convention readings still awaiting a yes), and gaps from
     coverage.md.
     Good: each line names its Q-nnn or REQ id and who can close it; "none"
     when there are none.
     Example: "- Q-007 (contradiction, inferred) retention period: the
     operations lead can close it." -->

- <Q-nnn or REQ-nnn, what is open, who can close it>

## Out of scope

<!-- What: what this backlog deliberately does not build: the PRD's
     non-goals and every REQ judged out-of-scope in coverage.md.
     Good: each line says where the decision is recorded (PRD non-goal,
     Q-nnn), so nobody re-adds it by accident.
     Example: "- Billing for lab tests (PRD non-goal 1)." -->

- <what is out> (<PRD non-goal | Q-nnn>)
