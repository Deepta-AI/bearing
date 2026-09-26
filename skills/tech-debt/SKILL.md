---
name: tech-debt
description: 'Keeps the tech debt register in docs/DEBT.md, seeded from TODOs, suppressed lints and skipped tests, ranked by cost of carrying it. Use when asked about "tech debt", "what should we clean up next" or "the debt register".'
argument-hint: "[seed|add \"<description>\"|review|pay <DEBT-nnn>] [--path <dir>]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(ls:*), Bash(mkdir -p:*), Bash(date:*), Bash(git ls-files:*), Bash(git log:*), Bash(git blame:*)
---

# tech-debt

Debt is a loan with interest. The register names what each item costs
every week and what paying it off costs once, so the next cleanup is
chosen by arithmetic rather than by whoever complains loudest.

Not this: `feature-flags` audits stale flags; `test-heal`
quarantines tests. Both feed rows here; neither replaces the register.

## Inputs

- register: `docs/DEBT.md`; if absent, created from `templates/DEBT.md`.
- files: `git ls-files` under `--path` or the repository root, minus
  `node_modules`, `vendor`, `dist`, `build`, `*.min.*`, `*.pb.go`,
  `*.generated.*`, `*.lock`; not a git repository: `Glob` with the same
  exclusions.
- marker patterns: `\b(TODO|FIXME|HACK|XXX)\b`; suppressions:
  `eslint-disable`, `@ts-ignore`, `@ts-expect-error`, `nolint`, `noqa`,
  `type: ignore`, `@Suppress`, `@SuppressWarnings`, `swiftlint:disable`,
  `#pragma warning disable`; skipped tests: `t.Skip(`, `pytest.mark.skip`,
  `it.skip(`, `test.skip(`, `xit(`, `xdescribe(`, `@Ignore`, `@Disabled`,
  `XCTSkip`; quarantine: `docs/testing/quarantine.md` rows and
  `quarantine` tags in test files.
- owner: the team owning the path in `CODEOWNERS`; if absent, the last
  author from `git blame -L <line>,<line> --porcelain`; else `unowned`.
- interest and principal: numbers the user gives; if absent, estimated
  from the item with the `est.` prefix (interest in hours per week,
  principal in hours).
- task id for `pay`: the id in the current branch name; if absent, ask
  once; with `BEARING_TRACKER=none` the row carries `task: none`.

## Steps

1. Inventory the four classes over the file list. Print "F files scanned:
   markers M, suppressions S, skipped tests T, quarantined Q". F of zero:
   stop non-zero. All four zero: a valid result, written into the
   register as "0 findings on <date>".
2. `seed`: one row per finding, grouped when the same text repeats in
   one file (count kept). Id `DEBT-nnn` continues from the highest in the
   register; ids are never reused. Description: the marker text or the
   suppressed rule or the skipped test name, with `file:line`. Interest
   `est.`: a skipped test is the regression it would have caught (high);
   a suppression is the bug class it hides; a marker is read for what it
   defers. Principal `est.` in hours. Trigger: when it must be paid
   ("before the next major", "when <file> is next changed", "quarantine
   deadline <date>"). Owner and date from Inputs. Idempotent: a row with
   the same file and text is not added again. Print added, already
   present, and rows whose marker is gone (moved to Paid with today).
3. `add "<description>"`: one row; ask once, in one message, for
   interest per week, principal, trigger and owner.
4. `review`: rank open rows by interest over principal; rows with an
   unknown number rank last under "needs an estimate". Rows whose
   trigger has fired (date passed, `git log -1 -- <file>` newer than the
   row's date, quarantine deadline passed) go to the top regardless.
   Print the top ten with triggers and the total interest per week.
5. `pay <DEBT-nnn>`: print the row, the files, the tests that prove it
   is paid, and the branch command (`start-task <TASK-ID> Pay<Name>`).
   When the fix lands, move the row to Paid with the date and the task
   id (or `task: none`).
6. Print the contract.

## Output contract

```
## Debt register: docs/DEBT.md (<mode>)
Scanned: F files; markers M, suppressions S, skipped tests T, quarantined Q
Rows: <open> open, <paid> paid (added A, already present P, paid this run K)
Total interest: <h> h/week (estimated E rows, measured M rows)
| Id | Description | Interest h/wk | Principal h | Trigger | Owner |
...
Triggers fired: K   Needs an estimate: U
```

## Gotchas

- A register nobody reviews is a longer TODO list. The template carries
  a monthly review date; the report says when the last review ran.
- Interest is what it costs now, every week: extra minutes per change,
  a slow test, an incident a quarter. Something that costs nothing
  weekly is a preference, not debt; it goes in a ticket.
- The grep counts are the seed, not the truth. A TODO pointing at a
  closed ticket is paid; a suppression with a reason comment may be
  right. Rank it low; never delete the row.
- `git blame` names the last person to touch the line, not who owes;
  the owner is the team that owns the path.
- Rows move to Paid with a date; they are never deleted, so the rate of
  repayment stays measurable.
- Line numbers drift; rows match on file and text.
- Quarantined tests carry a deadline from `test-heal`; a passed
  deadline is a fired trigger even when the test still passes nightly.
