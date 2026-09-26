# Quarantined tests

<!-- Template guidance: the list of flaky tests pulled out of the CI job
     because test-heal could not heal them. The team lead reads it to
     chase deadlines; test-run lists every row past its deadline at the top of its report as overdue. The row
     below is an example: replace it.
     What: one row per quarantined test, kept after release with its
     Released date.
     Good: the evidence shows passes and failures on the same commit and
     the heal that did not hold; every row has a task id and a deadline (14
     days unless given); never a regression, never a deleted row.
     Example: | TC-0063 applies a gift card | TC-0063 | US-06-004 |
     2026-09-23 | TASK-201 | 2026-10-07 | 50 runs on 9f8e7d6: 47 passed, 3
     failed; data heal did not hold | |
     Delete each comment when you fill its section. -->

A quarantined test is flaky (passes and fails on the same commit) and
could not be healed by `test-heal`. It carries the stack's quarantine
tag, is excluded from the CI job, still runs nightly and reports, and
has a task id and a deadline. A test past its deadline is reported as overdue by every test run until it is released or deleted.
A regression is never quarantined; it stays red. Nothing here is
deleted; a healed test gets a `released` date and keeps its row.

Tags: Playwright `@quarantine` in the title; pytest
`@pytest.mark.quarantine`; Go `//go:build !quarantine`; JUnit
`@Tag("quarantine")`; XCTest a `Quarantine` test plan; Maestro
`tags: [quarantine]`.

| Test | TC | Story | Quarantined | Task | Deadline | Evidence | Released |
| --- | --- | --- | --- | --- | --- | --- | --- |

<!-- Example rows, to show the shape; delete this comment and add real
     rows to the table above:
       | TC-0052 exports the monthly report | TC-0052 | US-07-003 | 2026-09-22 | TASK-188 | 2026-10-06 | 3 runs on a1b2c3d: pass, fail, pass; `waitForDownload` races the PDF worker; timing heal did not hold | |
-->
