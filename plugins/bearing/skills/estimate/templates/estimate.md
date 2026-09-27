# Estimate

<!-- Template guidance: what is left, what it costs in points, what the team
     can deliver before the real deadline, and the verdict with its margin.
     Every comment says what goes there (What), what a strong entry has
     (Good) and an example (Example). Delete each comment when you fill its
     section. -->

Backlog: docs/product/backlog.md   Sized: <date>   Team: <n people, source>
Previous estimate: <date and total, and what that total counted, or none>

## 1. Verdict

<!-- What: the answer to the question asked, first.
     Good: fits, fits only with cuts, or does not fit; the margin in points
     at the mean pace and at the worst sprint's pace, per priority tier;
     the proposed cuts by id or AC id and the fit after them; every cut
     marked Proposed, awaiting product and the client.
     Example: "Must 26 against capacity 24 at the mean pace (-2), 17 at the
     worst (-9): even the Musts do not fit. Proposed: split AC-US-00-014-5
     and -6 out of US-00-014 (Must 23, +1)." -->

## 2. Scope

<!-- What: which stories are remaining, which are excluded and why.
     Good: done and withdrawn stories named with their points, never
     re-sized; stories refused for missing AC; stories conditional on a
     decision (an ADR or the PRD's out-of-scope list) kept out of the plan.
     Example: "Excluded: US-00-001 to US-00-006 done (21 points);
     US-00-009 withdrawn." -->

## 3. Story sizes

<!-- What: one row per remaining story.
     Good: XS 1, S 2, M 3, L 5, XL 8; the previous size beside the new one;
     drivers named, including what the code check found; assumptions that
     would change the size, each confirmed by a file or marked unconfirmed:.
     Never shrink a size to fit a date.
     Example: "US-00-014 | Must | M 3 | L 5 | lab client is a stub (its
     test asserts NotImplementedError), new inbound email route | A3, A4" -->

| Story | Priority | Previous | Size | Points | Drivers | Assumptions |
| --- | --- | --- | --- | --- | --- | --- |
| US-nn-nnn | Must | | M | 3 | | A1 |

Assumptions:

- A1. <what is taken as true; confirmed by <file>, or unconfirmed:>

## 4. Capacity

<!-- What: the window and what the team can deliver in it.
     Good: completed (not committed) points per sprint from the log, mean
     and worst; the window from the next sprint start to the freeze, not
     go-live; person-days available after holidays and leave, with the
     arithmetic; any previous velocity assumption checked against the log.
     Example: "Completed 12, 9, 11 (mean 10.7, worst 9; committed 14 a
     sprint). 2 sprints to the freeze on Fri 6 Mar: 4 people x 20 days =
     80 person-days, minus 8 holiday and 10 leave = 62; 21.3 x 62/80 =
     16.5 points." -->

## 5. Gaps and calendar risks

<!-- What: what the backlog does not say and what points do not show.
     Good: requirements with no story, data the AC assume but nothing
     creates, claims the code contradicts, dependency cycles with a
     proposed break, ADR conflicts; each external lead time with its
     earliest start date, the time left to the freeze for the chain behind
     it, the action that pulls it in and a trigger date.
     Example: "Lab API keys: contract signed 2 Feb + 10 working days = 16
     Feb; 3 weeks left for US-00-014 and US-00-016. Trigger: no keys by 18
     Feb, both move out." -->

## 6. Plan

<!-- What: an order that respects dependencies and the dates in section 5,
     only when it adds information. Each phase ends with something a user
     can do.
     Good: every story placed after the stories it depends on; external
     lead times start on or after their trigger dates; no sprint loaded
     past its capacity from section 5.
     Example: "Sprint 4: US-00-012 and the report layout agreed. Sprint 5:
     US-00-014 once the lab keys land." -->

## 7. Task hours

<!-- What: hours for tasks in docs/product/tasks.md, only if it exists.
     Good: 1, 2, 3, 4, 6 or 8 per task for one person; over 8 is "split";
     the coverage gate's "tasks:" line verbatim or hand-summed:; stories
     under 3 or over 12 hours a point listed as mismatches. -->
