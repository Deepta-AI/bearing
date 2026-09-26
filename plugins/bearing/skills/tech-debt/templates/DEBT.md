# Technical debt register

<!-- Template guidance: the team's register of debt, each item priced as
     interest (hours a week it costs now) and principal (hours to pay it off
     once), so the next cleanup is chosen by arithmetic. The lead reviews it
     monthly; rows are never deleted. Every comment says what goes there
     (What), what a strong entry has (Good) and an example (Example). Delete
     each comment when you fill its section; keep the paragraph below. -->

Review cadence: monthly, first working week   Owner: <rotation>
Last seed: <YYYY-MM-DD> (<F> files; markers <M>, suppressions <S>, skipped tests <T>, quarantined <Q>)
Last review: <YYYY-MM-DD>   Total interest: <h> h/week

Interest is what the item costs per week (hours, `est.` when estimated).
Principal is the effort to pay it off (hours). Trigger is when it must be
paid. Ids are never reused; paid rows move to the Paid table with a date.

## Open

<!-- What: one row per unpaid item, seeded from TODO markers, suppressed
     lints, skipped and quarantined tests, or added by hand.
     Good: file:line plus the marker text or suppressed rule; interest is a
     weekly cost (minutes per change, a slow test), est. when estimated; a
     checkable trigger; the owner is the team owning the path, not the last
     blame author. No weekly cost means a ticket, not debt.
     Example: "DEBT-017 | t.Skip flaky upload retry (internal/upload/
     retry_test.go:88) | skipped test | est. 2 | est. 6 | when retry.go is
     next changed | payments-team | 2026-09-24" -->

| Id | Description (file:line) | Class | Interest h/wk | Principal h | Trigger | Owner | Added |
| --- | --- | --- | --- | --- | --- | --- | --- |
| DEBT-001 | <text> (<path>:<line>) | marker | suppression | skipped test | quarantine | other | est. <h> | est. <h> | <condition> | <team> | <date> |

## Needs an estimate

<!-- What: open rows whose interest or principal is unknown; they rank last
     in the review.
     Good: says which number is missing and who can supply it.
     Example: "DEBT-021 | nolint:gocyclo on the invoice builder | interest:
     ask billing how often it changes" -->

| Id | Description | Missing |
| --- | --- | --- |

## Paid

<!-- What: rows moved here when the fix lands, never deleted, so the rate
     of repayment stays measurable.
     Good: the paid date and the task id (or task: none); a marker that has
     disappeared from the code moves here on the next seed with that date.
     Example: "DEBT-009 | eslint-disable no-floating-promises in sync.ts |
     2026-09-12 | ENG-388 | 1.5" -->

| Id | Description | Paid on | Task | Interest saved h/wk |
| --- | --- | --- | --- | --- |

## Review log

<!-- What: one row per monthly review: the totals and what was decided.
     Good: the top item is the highest interest over principal, or a fired
     trigger (date passed, file changed since the row, quarantine deadline
     passed), which always goes first; the decision names an id and an owner.
     Example: "2026-10-05 | 23 | 3 | 14.5 | DEBT-017 (trigger fired) | pay
     DEBT-017 this sprint, payments-team" -->

| Date | Open | Paid this month | Interest h/wk | Top item | Decision |
| --- | --- | --- | --- | --- | --- |
