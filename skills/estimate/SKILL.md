---
name: estimate
description: 'Estimates the backlog: story points and task hours with assumptions, dependencies, a phase plan and a confidence range. Use when asked "how long will this take", "estimate the backlog" or "size the stories".'
argument-hint: "[path to the backlog, default docs/product/backlog.md] [team size]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(ls:*), Bash(mkdir:*), Bash(python3 *skills/backlog/scripts/coverage_check.py*)
---

# estimate

An estimate is a set of assumptions with a number attached. This skill
writes the assumptions down per story so the number can be challenged,
refuses to size what cannot be tested, and plans phases that each leave a
user with something to use.

## Inputs

- Backlog: looks in `$1` or `docs/product/backlog.md`; if absent, accepts
  a file path, a pasted story list or a tracker export, gives unnumbered
  stories ids `US-00-nnn` for this session and writes them into the
  estimate's story table; `backlog` produces the fuller backlog. Zero
  stories after one question stops the skill: "provide a backlog path or
  paste the stories with their acceptance criteria".
- Acceptance criteria: the `AC-US-` lines of each story; a story without
  any is refused whatever its source. That refusal stays.
- Tasks: looks in `docs/product/tasks.md` (the `| Task |` table from
  `backlog`); if absent, the task-hours step is skipped and the report
  says "0 tasks: hours not estimated"; stories are still sized.
- Hours gate: `coverage_check.py` from `backlog`, under
  `${CLAUDE_PLUGIN_ROOT}/skills/backlog/scripts/`; if absent, the
  hours are summed from the table by hand and the total is marked
  `hand-summed:`.
- Coverage: looks in `docs/product/coverage.md` for the REQ each story
  carries; if absent, the REQ column reads `none`.
- Constraints: looks in `docs/adr/*.md`; if absent, from the manifests
  (`go.mod`, `package.json`, `pyproject.toml`, `build.gradle*`) and README.
- Stack: the repository's CLAUDE.md snapshot; if absent, the manifests.
- Team size: `$2`; if absent, 1, marked `unconfirmed:`.
- Previous estimate: `docs/product/estimate.md`, for the previous column.
- Template: `templates/estimate.md` in this skill.

## Steps

1. Read the backlog from the source under Inputs. Collect every
   `US-[0-9]{2}-[0-9]{3}` heading not marked `withdrawn:` (or number the
   pasted stories). For each story count its `AC-US-` lines (or its
   Given/When/Then lines in a pasted story). Stories with zero AC go on
   the refusal list and are not sized; the run continues for the rest and
   the verdict is partial.
2. Read `templates/estimate.md` and the optional sources under Inputs,
   printing each as read or absent. If an earlier
   `docs/product/estimate.md` exists, keep its sizes in a "previous"
   column so the change is visible.
3. Size each story. Drivers, each one adds weight: new boundary (route,
   screen, message), schema change or data migration, third-party
   integration, new UI, more than four AC, an unconfirmed assumption.
   Scale: XS 1, S 2, M 3, L 5, XL 8. Write two to four numbered
   assumptions per story (existing component reused, library already in
   the repo, no design needed, and so on) and name the drivers. An XL is
   flagged "split with backlog"; it is sized but the flag is a gap.
4. Task hours. For every task in `docs/product/tasks.md` whose Estimate
   is `TBD` (and any the user asks to re-estimate), estimate hours for one
   person of the named discipline: 1, 2, 3, 4, 6 or 8. Drivers are the
   story's plus the task's own: a new table or migration, a third-party
   call, a new screen state, test data to build, a device or browser
   matrix. Anything over 8 hours is flagged "split" in the Task hours
   table and left `TBD` in tasks.md, never written as 12. Check the story
   against its tasks: a story whose task hours sit far from its points
   (under 3 or over 12 hours a point) gets a line under Gaps naming both
   numbers. Write the hours into tasks.md and the points into each
   story's `Points:` line and the story index of `docs/product/backlog.md`
   (Edit, only those cells). Run
   `python3 "${CLAUDE_PLUGIN_ROOT}/skills/backlog/scripts/coverage_check.py"`
   when present and copy its "tasks:" line into the backlog's "Hours by
   discipline" and the estimate; otherwise sum by hand, marked
   `hand-summed:`.
5. Dependency graph: `graph LR` in mermaid from every "Depends on" entry.
   Detect cycles by following edges; a cycle is listed under Gaps with
   the stories involved. Stories with no edges are still nodes.
6. Phase plan: phases of one to two weeks, ordered by dependencies then
   priority (Must before Should before Could). Each phase names its
   stories, its points, and one demo sentence a user could perform at
   the end. A phase whose demo sentence starts with "the backend" or
   "the schema" is re-sliced vertically.
7. Risks: at least one per phase and one per third-party integration,
   each with likelihood (low, medium, high), impact, mitigation and the
   story ids it threatens.
8. Total: sum of sized points. Band: low = 0.8 times the sum, high = 1.5
   times for a backlog with unconfirmed assumptions, narrowing to 0.9 and
   1.2 when every assumption is confirmed. Confidence low, medium, high
   by the share of unconfirmed assumptions (over a third, up to a third,
   none). Velocity in points per week is `$2` times a stated per-person
   figure, marked `unconfirmed:` unless the user gave it.
9. Write `docs/product/estimate.md` and print the counts.

## Output contract

```
## Estimate: <N> stories read from <backlog path>
Sized: S   Refused (no acceptance criteria): R (<US ids>)
Points: P (band L to H, confidence low|medium|high)
Tasks: T read, E estimated, X to split, K story/task mismatches
<coverage_check "tasks:" line, verbatim | hand-summed: hours by discipline>
Assumptions: A (U unconfirmed)   XL to split: X
Phases: K (<W> weeks at <velocity> points/week, unconfirmed:)
Dependencies: D edges, C cycles   Risks: Z
Written: docs/product/estimate.md
Verdict: complete | partial (R stories refused, C cycles)
```

## Gotchas

- No acceptance criteria, no estimate. A number on an untestable story
  is a promise nobody can check; send it back to `backlog`.
- Points measure size and uncertainty, not days. The story table never
  carries days; only the phase plan carries weeks, next to the velocity
  assumption that produced them. Task hours are the other lens: one
  person's effort on one task, never added to points or turned into a
  date on their own.
- A task estimate over a day is a task nobody can finish in a day. Flag
  it for `backlog` to split; do not write the big number into
  tasks.md, where the gate would fail it.
- Never shrink a size to fit a date. Cut scope in the phase plan instead
  and say which stories moved out.
- Do not invent sub-stories to split an XL here; flag it and leave the
  split to `backlog` so ids stay traceable.
- A dependency on a story that does not exist in the backlog is a gap,
  not a typo to fix silently.
