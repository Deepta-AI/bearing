# Progress: {task} {title}
<!-- The shared progress record for one task: docs/progress/<TASK-ID>.md,
committed on the task branch. progress.py writes it from this template
(start-task creates it, session-handoff and merge-request update it) and removes these
comments, so the committed file holds facts only. The detailed session log
stays in the ignored .bearing/state/ file; this file is what a second
engineer or a fresh clone reads. Keep it under 40 lines. -->

- Task: {task}
- Title: {title}
- Branch: {branch}
- Status: {status}
- Owner: {owner}
- Started: {started}
- Updated: {updated}
- Acceptance criteria: {criteria}

## Next
<!-- What: the single next action, one line.
Good: a verb and an object someone else could pick up ("write the failing
test for the refund rounding"), never "continue" or "keep going". -->
{next}

## Done
<!-- What: what landed, one short bullet each, newest last.
Good: names a commit, file or behaviour ("refund total rounds half-even,
test in refund_test.go"), not an activity ("worked on refunds"). -->
{done}

## Blockers
<!-- What: what stops progress and who can unblock it; "none" when nothing does.
Good: names the person or system and the question ("waiting on Priya: is
the refund cap per order or per day?"). -->
{blockers}

## Decisions
<!-- What: decisions taken on this task, each linked to its ADR.
Good: "use half-even rounding: docs/adr/0007-refund-rounding.md". -->
{decisions}

## Links
<!-- What: the merge request and the tracker ticket, "none" until they exist.
Good: full URLs someone can open without asking. -->
- MR: {mr}
- Ticket: {ticket}
