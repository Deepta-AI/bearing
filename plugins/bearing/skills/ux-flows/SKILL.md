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
2. Reconcile the spec with the code before drawing anything. The stories
   say what someone wants; the code says what ships today, and a flow
   written from the stories alone promises things the product does not
   do. For every action the flow touches, open its handler and write a
   short ledger in the package (section 0 of the template):
   - Rejections: every error code or message the handler can return,
     read from the code, not the story, including the lookup miss (an
     unknown id or token) and any path that throws outside the error
     type (a missing session or record dereferenced), which reaches the
     user as a generic 500. Each becomes its own error cell in step 4,
     with copy; a 500 path is also a backend note.
   - Who is calling: what each handler needs from the session (signed
     in, which account, which workspace or context) and what it does
     without it. A user arriving from outside (an email link, a
     notification) comes in every session state: signed out with no
     account, signed out with an account, signed in as someone else,
     signed in correctly. Trace each through the handlers: the sign-up
     that rejects an existing address, the sign-in that opens the wrong
     context for a user who belongs to two, the call that crashes when
     nobody is signed in. Each is a path in the flow.
   - Numbers and how they are counted: expiry, rate limits, quotas, seat
     or item caps, prices, sizes. Read the counting rule too: does the
     current user count, do pending items hold a slot, does an expired
     one still hold it, is the window fixed or rolling and is it shared
     (per workspace, not per user or per dialog). Then compute the
     numbers the user will see for the scenario in the request, on the
     date it happens ("a new Starter workspace can invite 4, not 5";
     "12 at $8 is $96 a month"; "10 a minute, so 2 wait"). A spec value
     that differs from the code changes every number derived from it
     (an invite still pending under the spec's expiry has expired under
     the code's, so it holds no seat and no longer blocks a re-invite).
   - Numbers other documents state: a PM note, a ticket or a review
     that quotes a count, a price or a date was usually worked out from
     the spec. Recompute it from the code and the records; where it
     differs, say so with both figures.
   - Routes and endpoints: every link, page and API call the flow relies
     on, checked against the router and the registered endpoints, and
     one hop further: when a recovery sends the user to an existing page
     ("go to billing to upgrade"), check that page's own control works.
     A link that points at an unregistered route, a step with no
     endpoint, or a field the record does not store (a name shown on a
     screen that no model carries) is `new` or a dependency, never
     described as existing.
   - Guards the handler does not make: what happens when the item changed
     between the user seeing it and acting on it (accepted, removed,
     expired, changed by another person). If the code succeeds anyway or
     gives a misleading reply, that is a state to design and a backend
     note.
   - Spec against code: each disagreement (a number, a permission, a
     missing path, an ADR the story contradicts) is a row with both
     sources. Until product decides, copy states what the code does, or
     reads the value from the record ("Expires 4 Oct, 14:00"); the spec's
     value never appears in copy or examples as fact. The conflict goes
     to open questions with what ships if nobody decides.
3. Screen inventory: one row per screen and per dialog. Id `S-01`, name,
   purpose in one sentence, story ids served, entry points, exits, and
   `reused` (with its route or component) or `new`. Every story maps to
   at least one screen; a story with none becomes an open question, never
   a silent gap. Every dialog lists a cancel, back or close in Exits.
4. State table per screen: loading, empty, error and success always;
   partial when the screen shows a list, a batch, or data from more than
   one source; offline when the feature writes data or targets a phone.
   Each cell says what the user sees and gives the copy. A cell that
   cannot occur reads `n/a: reason`, never blank. Copy rules: the button
   carries a verb; every error says what happened and gives a next step
   the user can take on that screen, a control or a pointer, even when
   the answer is "nothing to do" ("Ana is already a member. View her
   row."); the empty state invites the first action; no apology words.
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
    It fails on a screen with no outgoing edge that is not terminal, an
    inventory screen in no flowchart, a flowchart screen not in the
    inventory, a dialog with no cancel, back or close in Exits, a screen
    with no state table, a missing or blank loading, empty, error or
    success row, `n/a` without a reason, and zero screens read. Fix and
    rerun until it exits 0. Change nothing outside `docs/` (no README
    status line, no code). Print the output contract. If gstack
    `/diagram` is listed in this session, offer to render the mermaid;
    invoke only on a yes. Name `/plan-design-review` (gstack) as the
    heavier interactive review and `design-directions` as next.

## A product with several packages, or no code yet

- No handlers yet (a green-field product designed contract first): the
  API contract is what ships. Read each operation's error codes and
  response descriptions as its rejections, and head the ledger "from the
  contract, no code yet"; the limits come from the data model and the
  HLD. A conflict is then between the stories and the contract.
- No visitor accounts (a marketing site): the session walk covers the
  anonymous visitor and, where it exists, the staff sign-in; it does not
  invent account states the product does not have.
- One package per feature, one id space: screen ids continue from the
  previous package (the admin area starts after the public site's last
  id) and never repeat; the gate refuses an id two packages share.
- Site-wide stories (performance, accessibility, search, the design
  system) map to no screen. List them under "Site-wide, no screen of its
  own" with the sections that carry them (the state copy, the interaction
  inventory); they are not unmapped.
- Page chrome (header, footer, language switch, consent banner) is one
  group in the interaction inventory, "every page", not repeated per
  screen.
- Many rejections: one error row per rejection, labelled with its code
  (`error: slot_unavailable`); the recovery flows may group a screen's
  error rows by operation, each row named in the flow.

## Re-issuing with feedback

The previous version has readers: review notes, sign-offs and design
tickets cite its screen ids and its copy. The job is to change what the
feedback asks and to show every consequence, not to rewrite the package.

- Write `flows-v<n+1>.md` beside the previous file, which stays as is,
  with `## Changes from v<n>` first: each change, the feedback it answers
  and the screen ids touched.
- Screens the feedback does not touch are carried across with their copy
  and states unchanged, even when the previous version used another
  layout. Where the template wants a row the old screen never had, write
  `n/a: not in v<n>, outside this feedback` and list the gap as a note;
  do not design it. Correcting a value that contradicts the code (step 2)
  is the exception, recorded in Changes.
- A removed screen keeps its inventory row with `removed in v<n+1>` in
  Status (the gate then skips it; it leaves the flowcharts and state
  tables), and its id is never reused. Everything it carried is moved or dropped on purpose,
  each named in Changes: disclosures and prices, approved or legal
  wording, its error states, its events, the stories it served.
- Re-read every review note, sign-off and ticket that cites the previous
  version. Each one the change touches is listed with what now needs
  re-approval or rescoping: approved wording that has to change for the
  new case (a sentence written for one item, now for twelve) goes back to
  whoever approved it, and a ticket that cites a removed id is named.
- Re-run step 2 against the change: new inputs (a list instead of one
  item) meet the same limits many times over. Recompute the numbers for
  the feedback's own example, and recheck numbers the previous version
  stated. When the feedback cites a real case (a customer, a ticket, a
  pasted list), walk that case through the new flow with its own records
  and dates, item by item: which entries are dropped, refused, sent or
  left waiting, and why.

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
- Removing a confirmation removes its safety. Replace it in proportion:
  the parsed count on the button ("Send 12 invites"), or an undo or quick
  revoke after the send.
- Many items in one input (pasted addresses, uploaded rows): say which
  separators are accepted; normalise the way the server does (trim, case)
  and remove duplicates within the list on that normalised form; show the
  count and any unreadable entries before sending; report the result per
  item from the server's reply, since a check made before sending goes
  stale; let the user retry only the failures without retyping. Per-call
  limits and caps apply per item: say what happens to the ones over.
- Costs and counts before sending: show the unit price, the total for
  what will actually be sent, and when the charge happens. "Actually
  sent" means after duplicates, unreadable entries and everything the
  screen already knows will be refused: existing members and pending
  invites are on the page, so check against them before sending. Label
  that figure as what the page knows now (another admin or an accept
  can change it) and let the per-item server replies set the result.
- Work that outlives the screen: a paced or queued send (rate limit,
  long batch) meets a user who closes the dialog, navigates or loses the
  tab. Say what happens to the items still waiting: kept and resumed,
  or listed as not sent with a way to send them, never dropped silently
  and never shown as sent. A shared window (per workspace) can already
  be partly used by someone else, so pace from the server's refusals,
  not from a client-side count that assumes the first N go through.
- Time in copy: a date read from the record beats a duration; a stated
  duration is the code's value.
- Keep screen ids stable across versions so variants and reviews can cite
  them; add ids, never renumber.
- Never invent event names. The `needs event:` marker is the handoff to
  `analytics-events`.
- No em dashes; short sentences; diagrams in mermaid so they diff.
