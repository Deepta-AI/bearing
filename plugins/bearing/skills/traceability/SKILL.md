---
name: traceability
description: 'Builds the traceability matrix from requirements through stories, test cases, tests, commits and tickets, counting every gap; read-only. Use when asked "is everything traced", "traceability matrix" or "untested".'
argument-hint: "[base ref for git log, default the repository's first commit]"
allowed-tools: Read, Write, Grep, Glob, Bash(bash *bin/brg-tracker *), Bash(ls:*), Bash(mkdir:*), Bash(git log:*), Bash(git rev-list:*), Bash(git branch:*), Bash(python3 *skills/traceability/scripts/trace_check.py*)
---

# traceability

The chain is REQ, US, AC, TC, test, commit and MR, tracker ticket, docs,
event.
Every artifact in the kit carries its parent ids so this skill can walk the
chain with exact matches only. It reports; it does not repair.

## Inputs

- Product docs: `docs/product/PRD.md`, `docs/product/backlog.md`,
  `docs/product/coverage.md`, `docs/testing/test-cases.md`; if any is
  absent, the chain is built from what remains and the missing source is
  a gap class with the count of ids left unlinked, never a stop.
- Code and git: test files, `git log` from the base ref and branch names
  (`git branch -a`) for ticket ids; always read, so a repository with no
  product docs still yields tickets, commits, TC ids and ADRs.
- Design and operations docs: `docs/adr/`, `docs/design/`,
  `docs/runbooks/`, `docs/analytics/EVENT_SHEET.md`; if absent, their
  link counts are 0 and reported.
- Base ref: looks in `$1`; if absent, the repository's first commit.
- Tracker and prefix: `bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-tracker"
  config` (`tracker:` and `id prefix:` lines). `tracker: none` is not a
  gap: the ticket columns read `tracker: none`, and the two ticket gap
  classes are `n/a (tracker: none)`. If the script is absent, CLAUDE.md;
  if absent, any `[A-Z][A-Z0-9]*(-[0-9]+)+` prefix seen in commit
  subjects, reported as "prefix inferred".
- Template: `templates/traceability.md` in this skill.
- Gate: `scripts/trace_check.py` in this skill, Python 3 only, run from
  the repository root. It extracts the ids, builds the links and counts
  every gap class from the files and the git log it is given; the model
  never counts a gap itself.

## Steps

1. Inventory the sources and print each as read or missing:
   `docs/product/PRD.md` (REQ), `docs/product/backlog.md` (EP, US, AC),
   `docs/product/coverage.md`, `docs/testing/test-cases.md` (a table of
   TC id, story id, AC ids, written by `test-cases`),
   `docs/adr/*.md` (ADR-nnnn from the file number), `docs/design/*.md`,
   `docs/runbooks/*.md`, `docs/analytics/EVENT_SHEET.md`, test files
   (`*_test.go`, `*.test.ts`, `*.test.tsx`, `*.spec.ts`, `test_*.py`,
   `*Test.kt`, `*Tests.swift`), and the git log from base `$1` or
   `git rev-list --max-parents=0 HEAD` (read by the gate in step 4), and
   `git branch -a` for ticket ids in branch names. PRD or backlog
   missing: build what the remaining sources allow (ticket ids in commits
   and branches, TC ids in test names, ADR ids, US ids in tests and
   commits) and carry each missing source into step 4 as its own gap.
2. Extract ids with exact patterns: `REQ-[0-9]{3}`, `EP-[0-9]{2}`,
   `US-[0-9]{2}-[0-9]{3}`, `AC-US-[0-9]{2}-[0-9]{3}-[0-9]+`, `TC-[0-9]{4}`,
   ticket ids `<prefix>-[0-9]+` with the prefix from Inputs (a REST
   tracker's keys are whatever its server returns; take them as
   `brg-tracker get` prints them), `ADR-[0-9]{4}`,
   event names in backticks from the sheet's first column. Skip anything
   marked `withdrawn:`. Print the count per id class.
3. Build the links: REQ to US from `Covers:` lines; US to AC from the
   story body; AC to TC from the test-cases table; TC to test from
   `TC-` in test names or comments (US ids in tests count as a weaker
   link, reported separately); US to ticket from the story's `Ticket:`
   line or a commit naming both; ticket to commits from `[<KEY>]`
   subjects; US or ticket to ADR, HLD and runbook from mentions in those
   files; US to events
   from the story's tasks and the sheet's `Added in` column.
4. Run the gate, piping the log in the format it parses:
   `git log --format='@@commit %h%n%s%n%b@@files' --name-only <base>..HEAD | python3 "${CLAUDE_PLUGIN_ROOT}/skills/traceability/scripts/trace_check.py" --log -`
   (add `--prefix <P>` from Inputs, `--tracker none` when no tracker is
   configured, `--prd`, `--backlog`, `--cases` for other paths). It
   prints one `problem:` line per gap, the `Ids:`, `Links:`, `Gaps:` and
   `Unknown tickets:` lines, a `traceability:` counts line and the
   verdict, and exits 1 on any gap or when it read no id and no commit.
   The gap classes it computes: REQ without story; story without AC; AC
   without TC; TC without automated test; story without ticket; ticket
   without commits (both `n/a (tracker: none)` when no tracker is
   configured); boundary change without ADR (a commit touching
   `migrations/`, `auth`, a new route or a new dependency manifest whose
   ticket no ADR mentions); event named in a story but absent from the
   sheet. Tickets seen in commits but in no story go under "unknown
   tickets" so nothing is silently dropped. A missing source is a gap row
   of its own: `missing <path>: N <ids> could not be linked upward`, with
   the skill that writes it (`prd`, `backlog`, `test-cases`).
   New routes are not detected by the gate; name any the log shows under
   the boundary class by hand and say so. Ticket ids in branch names
   (`git branch -a`) that the gate did not list go under Unknown tickets
   with "(from branches)".
5. Write `docs/traceability.md` from `templates/traceability.md`: the
   sources table, id counts, link counts, the matrix (one row per REQ
   down to events), the gaps per class with the fixing skill
   (`backlog`, `test-cases`, the test itself, `start-task` and a
   commit with the id, `adr`, `analytics-events`), and the base ref.
6. The verdict is the gate's: traced only when it exits 0. Print its
   lines verbatim; a count the script did not print is not written.

## Output contract

```
## Traceability: <N> sources read, <M> missing (base <ref>, <C> commits)
Tracker: <rest | jira | gitlab | github | none> (prefix <P>)
<trace_check.py "Ids:" line, verbatim>
<trace_check.py "Links:" line, verbatim>
<trace_check.py "Gaps:" line, verbatim>
<trace_check.py "Unknown tickets:" line, verbatim> (plus any from branches)
<trace_check.py "traceability:" counts line, verbatim>
Written: docs/traceability.md
<trace_check.py "Verdict:" line, verbatim>
```

## Gotchas

- Never edit the audited artifacts. The fix list names the file, the id
  and the skill; the user runs it.
- A missing source is not a pass. No `test-cases.md` means every AC is
  an "AC without TC" gap, and the report says why.
- Exact ids only. "the login story" in a commit body is not a link; a
  US id mentioned in an unrelated file is a link and gets reported even
  when it looks accidental, so the user can correct it.
- Say which base ref the git log covered. A branch audit misses commits
  merged elsewhere; a full-history audit takes longer but is the one a
  release sign-off needs.
- Zero commits in range is a count to print, not an error, unless the
  backlog has tickets.
