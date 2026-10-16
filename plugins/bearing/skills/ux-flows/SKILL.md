---
name: ux-flows
description: 'Maps UX flows: screen inventory tied to stories, every state with copy, storyboard, flow diagrams and a zero dead-end check. Use when asked to "map the user flows", "what screens do we need" or "user journey".'
argument-hint: "<feature> [path to stories, PRD or ticket] [--feedback \"...\" to re-issue as the next version]"
allowed-tools: Read, Write, Edit, Grep, Glob, Skill, Bash(ls:*), Bash(mkdir:*), Bash(wc:*), Bash(grep:*), Bash(python3 *skills/ux-flows/scripts/flows_check.py*)
---

# ux-flows

A flow package says what the user sees at every step, including when the
thing fails, before anyone picks a typeface. Every screen names the stories
it serves, every screen has a way forward and a way back, and every state
has its copy written. Krug's rule governs the shape: three obvious clicks
beat one click that needs thought.

## Inputs

- Feature: looks in `$1`; if absent, asks one question.
- Spec: looks in `$2`; if absent, `docs/product/backlog.md` (stories whose
  epic or title names the feature, with `US-` and `AC-` ids); if absent,
  `docs/product/PRD.md`; if absent, asks once for a ticket or a pasted
  brief, numbered `US-LOCAL-001` by this skill. Nothing after that: stop
  with "provide stories, a PRD, a ticket or a brief".
- Existing screens: the code's routes, screens and page components, so
  names are reused; a green-field repository has none and every screen is
  marked `new`.
- The code behind the flow: the handlers, limits, plan or pricing tables
  and router the feature calls, and the ADRs; step 2 reconciles them with
  the spec.
- Event sheet: `docs/analytics/EVENT_SHEET.md`; if absent, the event
  column of the interaction inventory reads `no sheet` and no name is
  invented (`analytics-events` owns the taxonomy).
- Previous version: `docs/design/flows/<feature>/flows.md` or the highest
  `flows-v<n>.md`; with `--feedback`, or when the request asks for changes
  to it, it is the base for the next version (see Re-issuing with
  feedback), and its review notes (`docs/design/reviews/`) and the tickets
  citing it are read too; otherwise ask once whether to iterate or
  overwrite.
- Template: `templates/flows.md` in this skill. Checklist:
  `references/flow-review.md`.
- Gate: `scripts/flows_check.py` in this skill, Python 3 only, run from
  the repository root; it parses the written file's inventory, mermaid
  flowcharts and state tables, never the model's counts.

## Steps

1. Read the inputs; print each as read or absent. Write the user's goal
   in one sentence and list the stories with ids. Zero stories and no
   brief: stop as under Inputs.
2. Reconcile the spec with the code before drawing anything. Detail:
   references/reconcile-spec-with-code.md
3. Screen inventory: one row per screen and per dialog. Id `S-01`, name,
   purpose in one sentence, story ids served, entry points, exits, and
   `reused` (with its route or component) or `new`. Every story maps to
   at least one screen; a story with none becomes an open question, never
   a silent gap. Every dialog lists a cancel, back or close in Exits.
4. State table per screen: loading, empty, error and success always;
   partial when the screen shows a list, a batch, or data from more than
   one source; offline when the feature writes data or targets a phone.
   Detail: references/state-tables-and-copy.md
5. Journey storyboard: the goal, then one row per step with what the user
   does, sees, feels, and what the design does about the feeling. Close
   with the five-second read and the five-minute read.
6. Navigation map as a mermaid `flowchart` whose node ids are screen ids.
   Flow diagrams as `flowchart` or `sequenceDiagram`: the happy path, each
   alternate path, and one error-recovery path per error cell in step 4.
7. Decision points and dead-end check: list every branch with its
   condition and the screen ids on each side. For every screen record the
   way forward and the way back. A screen missing either is a dead end:
   add the exit. A screen that legitimately ends the journey says
   `terminal: <reason>` in its inventory Exits cell (or
   `%% terminal: S-nn <reason>` in a flowchart). The gate counts the dead
   ends from the mermaid; the count must be zero.
8. Interaction inventory: every control on every screen with label, type,
   target size (44 px touch, 24 px pointer), keyboard path, and the
   analytics event: the sheet's name, or `no sheet`, or
   `needs event: <proposed>`.
9. Open questions: each with an owner (a role, never a person the run
   invented), a date, and what ships if it is deferred ("engineer ships
   48-hour links and copy that reads the date from the invite").
10. Self-review against `references/flow-review.md`. Fix what can be
    fixed; list what stays open with the check id. F2 (dead ends) and F4
    (state coverage) take their result from the gate, not from reading.
11. Write `docs/design/flows/<feature>/flows.md` from `templates/flows.md`
    (with `--feedback`, see below). Run the gate:
    `python3 "${CLAUDE_PLUGIN_ROOT}/skills/ux-flows/scripts/flows_check.py" --file <the file written>`.
    It fails on a screen with no outgoing edge that is not terminal and on
    more cases. Detail: references/gate-and-handoff.md. Fix and
    rerun until it exits 0. Change nothing outside `docs/` (no README
    status line, no code). Print the output contract. If gstack
    `/diagram` is listed in this session, offer to render the mermaid;
    invoke only on a yes. Name `/plan-design-review` (gstack) as the
    heavier interactive review and `design-directions` as next.

## A product with several packages, or no code yet

No handlers yet, no visitor accounts or several packages change the ledger
and the ids: screen ids continue across packages and never repeat (the gate
refuses an id two packages share). Detail: references/several-packages-or-no-code.md

## Re-issuing with feedback

- Write `flows-v<n+1>.md` beside the previous file, which stays as is,
  with `## Changes from v<n>` first: each change, the feedback it answers
  and the screen ids touched.
  Detail: references/re-issuing-with-feedback.md

## Output contract

```
## UX flows: <feature> (v<n>)
Path: docs/design/flows/<feature>/flows.md | flows-v<n>.md
Source: backlog | PRD | ticket | pasted brief   Stories: N (unmapped: 0 | K)
Spec against code: N conflicts (each in open questions), R rejections read from code
Screens: N (dialogs: M, reused from code: R, new: W)
States: N cells filled (n/a: K, copy proposed: P)
Flows: N (happy 1, alternate A, error recovery R)
<flows_check.py "Dead ends:" line, verbatim> (above 0: the run is not done)
<flows_check.py "ux-flows:" counts line, verbatim>
Controls: N (events from sheet: E, needs event: U | no sheet)
Open questions: N (owners assigned: N)
Review: N checks, N pass, N fixed, N open (F2 and F4 from flows_check.py)
Render: offered (/diagram) | mermaid only
Next: design-directions <feature>
```

A count the script did not print is not written.

## Gotchas

- A state cell that says "shows a spinner" is not filled. The copy is the
  deliverable; the spinner is a given.
- A dead end is a defect in the package, not a finding to report. Fix it
  before printing counts.
- Fewest steps means fewest thoughts. Merging two decisions into one
  puzzling choice saves a click and costs the user more.
- Dialogs and confirmations are screens. A dialog with no cancel is a dead
  end; a destructive action with no undo window is an open question.
- Many items in one input, costs and counts before sending, a removed
  confirmation and work that outlives the screen each carry rules the
  package must show. Detail: references/batches-costs-and-queued-work.md
- Time in copy: a date read from the record beats a duration; a stated
  duration is the code's value.
- Keep screen ids stable across versions so variants and reviews can cite
  them; add ids, never renumber.
- Never invent event names. The `needs event:` marker is the handoff to
  `analytics-events`.
- No em dashes; short sentences; diagrams in mermaid so they diff.
