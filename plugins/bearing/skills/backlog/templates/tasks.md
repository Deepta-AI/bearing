<!-- Template guidance: docs/product/tasks.md, the development and test
     tasks for every live story in one table, so a sprint can be planned
     and a tracker or a table-to-CSV exporter can import them. backlog
     writes the rows with Estimate TBD; estimate fills the hours. The
     coverage gate parses the table: keep the header row and its column
     names, and one row per task. Every comment says what goes there
     (What), what a strong entry has (Good) and an example (Example).
     Delete each comment when you fill its section. -->

# Tasks

Backlog: docs/product/backlog.md   Built: <date>   Hours: <TBD | estimate on date>

## Task table

<!-- What: one row per task, grouped by story, development tasks (D) before
     test tasks (T).
     Good: the id is US-nn-nnn-Dk or US-nn-nnn-Tk and never reused;
     discipline is one of backend, frontend, mobile, qa, devops, design, content (a test task
     is qa; schema and migration work is backend); Estimate is hours, at
     most 8 (a day of one person's work; more is two tasks), or TBD; Depends
     on is task ids or none; Done when is a state someone can check without
     asking the author; Verifies names the AC ids the task moves toward (a
     development task with none writes none: <reason>). Every story has at
     least one D and one T task, and every AC is verified by a T task.
     Example: "US-00-014-D2 | US-00-014 | backend | Match endpoint: name and
     date of birth lookup | 6 | US-00-014-D1 | POST /reports/{id}/match
     returns the candidate patients, ranked, in under 300 ms on the seed data
     | AC-US-00-014-1, AC-US-00-014-2" -->

| Task | Story | Discipline | Title | Estimate (h) | Depends on | Done when | Verifies |
| --- | --- | --- | --- | --- | --- | --- | --- |
| US-nn-nnn-D1 | US-nn-nnn | backend / frontend / mobile / devops / design / content | <one line, names the layer it touches> | TBD | none | <checkable end state> | AC-US-nn-nnn-1 |
| US-nn-nnn-T1 | US-nn-nnn | qa | <which criteria it proves, and how> | TBD | US-nn-nnn-D1 | <cases written and passing> | AC-US-nn-nnn-1, AC-US-nn-nnn-2 |
