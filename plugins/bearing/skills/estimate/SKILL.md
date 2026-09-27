---
name: estimate
description: 'Estimates the backlog: story points and task hours with assumptions, dependencies, a phase plan and a confidence range. Use when asked "how long will this take", "estimate the backlog" or "size the stories".'
argument-hint: "[path to the backlog, default docs/product/backlog.md] [team size]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(ls:*), Bash(mkdir:*), Bash(python3 *skills/backlog/scripts/coverage_check.py*)
---

# estimate

An estimate is a set of assumptions with a number attached, and the
question behind it is almost always a date: "how many weeks", "do we make
go-live". This skill sizes only the work that is left, checks each story
against the code and the decisions before sizing it, turns points into
calendar time with the team's measured pace and real availability, and
answers the date question with a margin, not a mood.

## Inputs

- Backlog: `$1` or `docs/product/backlog.md`; if absent, a file path, a
  pasted story list or a tracker export (unnumbered stories get ids
  `US-00-nnn` for this session). Zero stories after one question stops the
  skill: "provide a backlog path or paste the stories with their
  acceptance criteria".
- Acceptance criteria: the `AC-US-` lines (or Given/When/Then lines) of
  each story; a story without any is refused a firm size whatever its
  source.
- Status: each story's `Status:` line or index cell. Done and withdrawn
  stories are read for velocity and history, never re-sized.
- Sprint log: `docs/product/sprints.md` or any file with per-sprint
  committed and completed points; if absent, velocity is `unconfirmed:`.
- Calendar: release plan, milestones, code freeze, UAT, holidays and leave
  (`docs/product/release-plan.md`, `docs/team/`, the README's Team
  section, any file named calendar, leave or holidays). Print what was
  found; if nothing, say "no leave or holidays known" in the answer.
- Decisions and scope: `docs/adr/*.md` and the PRD, including its
  requirement list and its out-of-scope list.
- Code: the modules, schema and tests the remaining stories touch.
- Tasks: `docs/product/tasks.md` (the `| Task |` table from `backlog`); if
  absent, task hours are skipped and the report says "0 tasks: hours not
  estimated".
- Hours gate: `coverage_check.py` under
  `${CLAUDE_PLUGIN_ROOT}/skills/backlog/scripts/`; if absent, hours are
  summed by hand and marked `hand-summed:`.
- Team size: `$2` or the user's words; else the repository's; else 1,
  marked `unconfirmed:`.
- Previous estimate: `docs/product/estimate.md`.
- Template: `templates/estimate.md` in this skill.

## Steps

1. Scope the remaining work. List every story with its status. Done and
   withdrawn stories leave the total (name them and their points once so
   the reader sees they were excluded). A story In progress is sized for
   what is left, judged from the code, not its full size. Stories with no
   AC go on the refused list; any guess for one is labelled a guess and
   kept out of the headline figure.
2. Check each remaining story before sizing it. These checks find the work
   the story text hides, and they are where estimates go wrong:
   - Claims against code. Where a story, README or note says a part
     exists ("uses the existing client", "already built"), open the code
     and its tests. A stub, a `NotImplementedError` or a test asserting
     absence means the story includes building it.
   - Data the AC assume. For every noun an AC treats as known (a price,
     a status, a link sent to someone), find the field, table or story
     that creates it. None is a gap, raised, not silently
     added to a story.
   - Requirements with no story. Map each live PRD requirement to a story;
     one with none, or a Depends on naming a story that is not in the
     backlog, is a gap. Say whether the weeks include it and at what
     guessed size.
   - Decisions. A story that contradicts an Accepted ADR or the PRD's
     out-of-scope list is not ordinary scope: size it only as conditional
     on product reversing the decision, keep it out of the plan, and say
     who decides.
   - ADR consequences. Each ADR's consequences (a provider's onboarding,
     per-user verification, asynchronous confirmation, infrastructure
     "we do not run yet") become drivers of the stories they touch and,
     where they need someone outside the team, lead-time items for step 5.
   - Dependency cycles, by following Depends on edges; a cycle is a gap
     with a proposed way to break it, never an edited Depends on line.
3. Size. Scale XS 1, S 2, M 3, L 5, XL 8. Drivers add weight: a new
   boundary (route, screen, message, webhook), a schema change or
   migration, a third-party integration, new UI, more than four AC,
   anything found in step 2, an unconfirmed assumption. Give each story
   its drivers and the assumptions that would change its size, each
   confirmed by a file or marked `unconfirmed:`. Calibrate against the
   sprint log: if a finished story took far more than its points (the
   notes say so), size its look-alikes from what it actually took. An XL
   is flagged "split with backlog". Re-estimating: put the previous size
   beside the new one; a story whose AC grew is re-sized, never carried
   over.
4. Capacity from evidence, not assumption.
   - Velocity is completed points per sprint from the log, never
     committed points. Use every recent sprint, report the mean and the
     worst, and note when the team routinely commits more than it
     finishes.
   - The window ends at the last day story work can merge: code freeze,
     hardening or UAT start, not the go-live date. Count it in sprints
     from the next sprint start.
   - Availability. Count working days in the window per person, minus
     office holidays and planned leave: capacity = mean velocity per
     sprint x sprints in the window x (available person-days / full
     person-days). Show the arithmetic. Past sprints shortened by a
     holiday are normalised the same way before averaging, or the effect
     is stated.
   - A velocity or pace from a previous estimate is checked against the
     log; if the log contradicts it, say so and by how much.
5. Calendar risks points do not show. For every item that needs someone
   outside the team (provider credentials after KYC, an ops ticket, a
   client decision), compute the earliest date the dependent work can
   start (count working days, skip holidays) and the time left from then
   to the freeze for that story and everything that depends on it. A
   serial chain after a late start cannot be sped up by the other
   developers; it is its own fit check. Name the action that pulls the
   date in (submit now, chase the ticket) and a trigger date after which
   the chain is out.
6. Verdict. Compare remaining points with capacity at the mean pace and
   at the worst sprint's pace, per priority tier: Must, then Must plus
   Should, then all. State the margin in points each way. If it does not
   fit, propose what moves out (Could, then Should, then parts of a Must
   split by AC, each named by id or AC id) and show the fit after the
   cut. If even the Musts do not fit, say so plainly and give the
   options (split a Must by AC, move the date, or add people with the
   ramp-up cost counted) rather than a plan that only works at the best
   pace. Cuts and splits are Proposed for
   product and the client; never shrink a size to fit.
7. Plan, only when it adds information: an order that respects
   dependencies and the dates from step 5, each phase leaving something
   a user can do.
8. Task hours, when tasks exist. For tasks with Estimate `TBD`, hours for
   one person of the named discipline: 1, 2, 3, 4, 6 or 8; over 8 is
   flagged "split" and left `TBD`. A story whose task hours sit under 3 or
   over 12 per point is listed as a mismatch. Run
   `python3 "${CLAUDE_PLUGIN_ROOT}/skills/backlog/scripts/coverage_check.py"`
   when present and copy its "tasks:" line; otherwise `hand-summed:`.
9. Write `docs/product/estimate.md` from the template. In the backlog
   change only `Points:` values and the index's Points cells: no notes, no
   new headings, no status, priority, AC or dependency edits. Nothing
   outside docs/ changes.
10. Answer in the final message: the verdict and margin first, then the
    gaps and calendar risks, then which inputs are assumptions rather
    than facts from the repository. Nobody confirmed an assumption unless
    the user said so in this conversation.

## Output contract

```
## Estimate: <N> stories read from <backlog path>
Remaining: S sized, R refused (<ids>), D done or withdrawn excluded (<points>)
Points: P remaining (Must M, Should S, Could C); previous: <total, what it counted>
Velocity: mean V, worst W completed points per sprint (<sprints>); committed avg C
Window: <start> to <freeze>, K sprints, A of F person-days available -> capacity X (worst Y)
Verdict: fits | fits only with cuts | does not fit; margin <+/- points> at mean, <at worst>
Proposed cuts: <ids or AC ids, or none>
Lead-time risks: <item, earliest start, time left to freeze, stories>
Gaps: <missing stories, missing data, contradicted claims, ADR conflicts, cycles>
Tasks: T read, E estimated, X to split, K mismatches | 0 tasks: hours not estimated
Written: docs/product/estimate.md
```

## Gotchas

- Done work is history, not scope. Re-sizing a finished story inflates the
  total and double-counts velocity.
- Committed is a wish; completed is the measurement. A team that commits
  14 and finishes 10 has a velocity of 10.
- Go-live is not the deadline for code. Freeze, hardening and UAT come
  first; sizing against go-live overstates capacity by weeks.
- Measured velocity already includes a normal sprint's interruptions, but
  not a holiday week or a fortnight's leave in the window ahead. Those are
  subtracted explicitly.
- A README or story that says something is built is a claim; the code and
  its tests are the evidence.
- External lead times (KYC, credentials, infra tickets, client sign-off)
  do not shrink with velocity. A Must behind one is a date risk even when
  the points fit.
- No acceptance criteria, no firm size. A number on an untestable story is
  a promise nobody can check.
- Points measure size and uncertainty, not days. Only the capacity line
  turns them into time, next to the velocity that produced it.
- Never shrink a size to fit a date; move scope out and name it.
- Do not add stories, split stories or fix dependencies in the backlog;
  propose them. Ids are referenced from tests and commits.
