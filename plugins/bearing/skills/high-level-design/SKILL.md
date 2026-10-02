---
name: high-level-design
description: 'Writes a High Level Design (HLD): goals and non-goals agreed first, then architecture, data, interfaces, failure modes, rollout. Use when asked for an "HLD", "system design" or "an architecture overview".'
argument-hint: "<title> [path to PRD or notes] [--continue after the goal is agreed]"
allowed-tools: Read, Write, Grep, Glob, Skill, Agent, Bash(python3 *skills/high-level-design/scripts/arch_check.py*), Bash(bash *bin/brg-kit-paths*)
---

# high-level-design

An HLD says what the system delivers, what it deliberately does not, and
where it breaks. Every claim about the existing system comes from the
code; anything else is prefixed "assumption:" so reviewers can see it. A
failure-mode cell nobody can fill is written as `UNDEFINED`, never left
blank. Beside the HLD it writes the architecture set a team builds from:
tenets, the decisions index with the conflicts it settled, and the repo
plan. An independent review grades it, and an open BLOCKER keeps it from
Approved.

Not this: `low-level-design` refines one component into files, queries and MRs;
this stops at the component boundary.

## Inputs

- Title: looks in `$ARGUMENTS`; if absent, asks one question.
- Requirements and stories: looks in the path given, else
  `docs/product/PRD.md` and `docs/product/backlog.md`; if absent, the
  README and the routes, screens and tables in the code; zero ids after
  that gets one question for the stories or a brief, and a pasted brief
  is written into section 1 with `Serves: unnumbered`; `prd` and
  `backlog` produce the fuller chain.
- Data model: looks in `docs/design/data-model.md`; if absent, the
  migrations and schema in the code; if none, the reconciliation covers
  ADRs against stories only and says so.
- Decisions: looks in the ADR directory found the way `adr` finds it
  (default `docs/adr/`); if absent, the Decisions first protocol below
  records them, and any choice it does not cover is written as "ADR
  needed".
- Templates: looks in `docs/templates/HLD.md`; if absent, this skill's
  `templates/HLD.md`; always `templates/tenets.md`,
  `templates/architecture-decisions.md` and `templates/repo-plan.json`.
- Standard stack: the defaults in
  `${CLAUDE_PLUGIN_ROOT}/skills/tech-decision/references/catalogue.md`; if
  unreadable, every named technology is listed under section 13.
- Kit stacks: the ids in `*/templates*/stack.json` under each skill
  root `bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-kit-paths"` prints (Glob and
  Read; the stacks ship in bearing-backend and bearing-apps, and none
  installed means none to choose from, said as such); a component none fits gets `"stack": "none"` and a
  `stack_note`.
- Project name and group: `.bearing/company.json` and the git remote;
  if absent, one question for the PascalCase project name, which is also
  the group.
- Delivering entity: looks in `.bearing/company.json`; if absent, the title
  page reads "unattributed" and the run continues.
- Existing system: the code, for every component named; a green-field
  design has none and every claim is prefixed "assumption:".
- Task id: `.git/HEAD` names the branch; a task id in it goes on the
  title page, else `Task: none`.
- This skill runs in the main conversation, not forked: it needs the
  Skill tool for `tech-decision`, the Agent tool for `critic` and the
  user's yes on section 1, none of which a forked document writer has.
  Its only shell is the gate script.

## Steps

**Revising.** When the output file already exists, this run is a
revision: read `${CLAUDE_PLUGIN_ROOT}/skills/adr/references/revision-protocol.md`
and follow it (version line, changes table, superseding ADR,
critic on changed sections, downstream list). A revision that leaves the goal and non-goals as they were keeps section 1 agreed and skips step 2's question; a changed goal goes back through step 2.
A section the revision changes is re-sourced, not edited from the old
text: re-read the code, README and ADRs behind it as step 4 asks, and
recompute its numbers. The previous version's conclusions are claims to
check, not inputs; one that no longer holds, or never did, is a row in
the changes table. Check what was actually built before writing about
cutover: grep for the old design's handlers, tables and flags, because a
design that was approved but never built has no data or jobs to migrate.
Change what the request changes and what it invalidates, nothing else;
a problem noticed elsewhere in the old design goes under open questions,
not into a redesign nobody asked for. Tenets and decisions you touch
must agree with the revised text.

**Decisions first.** Before building, run `tech-decision` for the keys
compute, messaging, database, analytics store, cache, search, auth, api
style. `tech-decision` asks only about the keys this task needs that no
accepted ADR, the request or the code already settles, one question at
a time, and records only what the user decides; a key still
awaiting an answer follows
${CLAUDE_PLUGIN_ROOT}/skills/tech-decision/references/decision-protocol.md.
Run it with the Skill tool; a key awaiting the user or deferred is
listed under "ADRs needed", with no ADR written for it.

1. Title from `$ARGUMENTS`; inputs from the sources under Inputs, each
   printed as read or absent. Read the template (repository copy when
   present, else `templates/HLD.md`). Collect the ids the design serves
   (`REQ-nnn`, `US-nn-nnn`, `<PREFIX>-<n>`, `ADR-nnnn`) and put them at the top
   of the document. Zero ids found: ask the one question under Inputs,
   then continue with what it yields.
2. Without `--continue`: write section 1, goal and non-goals, into
   `docs/design/<kebab-title>-hld.md`. Three sentences for the goal, a
   list for the non-goals. Ask the user "agree the goal and
   non-goals?" and wait. On a yes, go on; on changes, rewrite section 1
   and ask again; when the user stops here, print the contract with
   `Waiting for: agree section 1`. With `--continue` (a later session):
   read section 1 from the file as agreed and go on. Never draft section
   2 onward before the yes.
3. Fill sections 2 to 12 in template order:
   - users and flows: numbered steps per actor, two or three flows;
   - architecture: one mermaid diagram, then one paragraph per component
     (responsibility, owner, what it talks to and how);
   - data: entities, store, retention, migrations implied; point at
     `data-model` for the full model;
   - interfaces: every API, event and message, with the contract path
     (`api/openapi.yaml`, a schema file, an event sheet);
   - external integrations: each third party on the runtime path, what
     the user sees when it is down, slow or rate limited, and where its
     credential lives; then "Deliberately not integrated", each with the
     reason;
   - failure modes: one row per component with what fails, how it is
     noticed, what the user sees, how it recovers; an unknown cell is
     `UNDEFINED`;
   - scaling and limits: expected load, the worst window (see Traps,
     peaks), first bottleneck, and the number at which the design stops
     working; a limit shared with other traffic (a provider plan, a
     pool, a table) is budgeted net of that traffic at the same hour,
     and a limit enforced per process is multiplied by the number of
     processes the design runs. When no design choice meets a
     requirement inside today's limits, say so with the arithmetic and
     name who must decide (a bigger plan under a new ADR, or a PRD
     change); never meet it silently by reinterpreting the requirement;
   - security and privacy: auth model, authorisation per resource, PII
     touched, secrets needed;
   - observability: logs, metrics, traces, alerts with runbook names;
   - analytics: event sources, the store, the business question each
     answers and the reporting path, kept apart from the audit trail;
   - rollout and rollback: flags, phases, migration order, how to back
     out at each phase, and what happens to work in flight at each
     cutover (queued jobs, pending rows, open sessions) going forward
     and going back. The back-out target exists today or is built in
     this plan; "fall back to the old path" when the old path was never
     built is not a back-out.
     Architecture, data, external integrations, scaling, security,
     observability, analytics and rollout each end with
     "**Risks this leaves open**" and at least one bullet.
4. Source every claim. Grep the code for each component, route, table
   and queue you name. A claim with no source is prefixed "assumption:".
   A store, queue or auth choice with no ADR behind it is written as
   "ADR needed: <title>" and never decided silently.
5. Standard stack and repos. Section 13 lists every technology the ADRs
   commit to that is not a catalogue default, with its ADR and "needs
   Architect or Engineering Manager sign-off". Write
   `docs/architecture/repo-plan.json` from `templates/repo-plan.json`:
   one entry per repository, name `<Project><Component>` PascalCase,
   `git_path` `<group>/<Client|Server|Infrastructure>/<name>`, `stack` a
   kit stack id, `tech`, `responsibility`, and `apps[]` (path, name, for)
   for a monorepo. An entry whose code lives in the repository that
   holds these documents gets `"path": "."` (a small team often keeps
   one repository for the PRD, the designs and the code); ask whether it
   does when the request does not say, and record the answer as an open
   question until it is given. `new-repo` creates each other entry from
   its stack and name (autopilot's repos stage does it for every entry,
   beside the run's repository); this skill creates none. Mirror it as the section 14 table.
6. Tenets. Write `docs/architecture/tenets.md` from `templates/tenets.md`:
   five to eight, each a bold checkable rule, why this team needs it, and
   "A breach looks like:" with a concrete bad merge request. A tenet
   nobody could plausibly break is dropped.
7. Reconcile. Read every ADR, every acceptance criterion and the data
   model; each contradiction between them (a table an ADR assumes and
   the model lacks, a criterion an ADR cannot meet, two ADRs naming
   different services) is a conflict. Write
   `docs/architecture/decisions.md` from
   `templates/architecture-decisions.md`: the index (one row per ADR
   file: id, title, area, status, reversibility) and one entry per
   conflict with the question, Between, Decision, Why, Settled by and
   What now has to change to match. Propose each decision and ask the
   user one conflict at a time; Settled by is the person or role who
   answered, "Proposed" under `autopilot`, or "open". Never edit an
   Accepted ADR to match; name the superseding ADR under What now has to
   change. None found: one "None found:" line naming what was compared.
8. Summary and components, written last: the two-sentence summary, the
   line `Diagram: docs/architecture/diagrams/<Project>_SystemArchitecture_v<N>.svg`
   (`architecture-diagram` draws it from
   `docs/architecture/architecture.json`; not drawn yet is reported, not
   faked), and the "What gets built" table whose Repository column names
   the repo-plan entries. Section 15 gives the counts.
9. Review, mandatory. Fork `critic` (Agent tool) in graded mode with
   the HLD, the ADR directory, `docs/architecture/`, the backlog, the
   data model and the Traps list below, asking it to check each trap that
   applies. Write its findings verbatim under section 16 with
   `Reviewed by: critic, <date>` and `Status: open` on each. Fix
   what the user agrees to, marking it `fixed (<where>)`, or record who
   accepted it. Status stays Draft or Reviewed while a BLOCKER is open.
10. Open questions and assumptions (section 17), each with an owner and a
    date. Write the HLD, then run the gate:
    `python3 "${CLAUDE_PLUGIN_ROOT}/skills/high-level-design/scripts/arch_check.py" docs/design/<kebab-title>-hld.md --adr-dir <ADR directory>`.
    Fix every problem it prints and rerun until `Gate: passed`; a
    problem you cannot fix goes in the contract. Print the output
    contract.

## Traps

What separates a design that survives review from one that reads well.
Check each against the draft before step 9; each one that applies gets a
sentence in the section named, with the repository's numbers. The critic
in step 9 is given this list and checks the draft against it too.

- **Peaks (scaling).** Size for the worst window, not the average or the
  first burst you find. Overlay every family of due times (each offset
  from each cluster of start times: a 24 hour reminder for tomorrow's
  09:00 lands with today's 2 hour reminders for 11:00) and the shared
  limit's other traffic at that same hour. Compute the count, divide by
  the net rate, compare with the requirement.
- **Check then act (failure modes).** A condition that guards a side
  effect (status, opt-out, a switch, a version) is read at the moment of
  the side effect, or the state change and the queued work change in one
  transaction. A check at enqueue or claim time leaves a window as long
  as the queue ahead of it; state the window or close it. A message
  payload is a snapshot, not the truth; re-read the row.
- **Side effect then record (failure modes).** For every external call
  followed by a local write (send then mark done, publish then commit
  the offset), a crash between them gives a duplicate or a loss. Say
  which the design accepts, make the retry policy agree, and name the
  provider's idempotency key, looked up in its documentation (see
  Provider facts); a retry without one sends the side effect twice.
- **Two systems, one change (data).** A database write plus a publish or
  a call is not atomic. Use an outbox read by a relay that retries, or
  state which orphan or loss results.
- **Parallelism (scaling).** More workers over a table need a claim (row
  lock with skip, or a status change before work); more consumers over
  a per-process limiter multiply the rate.
- **Retries are bounded by usefulness (failure modes).** Every retry
  has a deadline after which the work is dropped (a reminder after the
  appointment is noise). A retry that blocks an ordered partition or
  queue holds up everything behind it; say where retries wait.
- **Late arrivals (flows).** Work created after its due time (a booking
  inside the reminder window) is sent at once, skipped, or partly sent;
  pick one.
- **Controls (rollout).** A pilot list, kill switch or transport flag
  is operator owned and separate from any setting users own. Reusing a
  user's switch (a clinic's own on/off) for a pilot overwrites their
  choice and cannot be told apart from it later; check every default.
- **Growth (data).** Each new row stream gets a rows-a-day number and a
  retention rule, especially rows in a table something polls.
- **The numbers agree with each other.** Batch sizes, lease or stale
  claim timeouts, poll intervals and retry deadlines are checked against
  the rate the design states (a lease shorter than the time to send the
  batch it claims resends or drops the tail).
- **Authority the code lacks (security).** A requirement that names a
  role (an admin, an owner) needs an auth model; if the routes are open
  today, say so and list it as needed, never as existing.
- **Repeated requests (interfaces).** A client repeats writes: a double
  tap, the back button, a network retry. Every write endpoint takes a
  request id the client makes once, stored under a unique constraint, and
  a repeat returns the first result with no second row and no second side
  effect. A form-only guard (a disabled button) does not cover retries.
- **Untrusted content (security).** Text the system shows but did not
  write (social posts, reviews, names from forms, anything fetched) is
  rendered as text, never as markup, and its media comes only from named
  hosts. Staff or admin sessions live on a separate origin from pages that
  show such content, so a script that slips onto a public page cannot use
  a staff session.
- **Model output on a public path (security).** An LLM answer shown to
  people who are not staff is grounded (the model sees only retrieved
  passages), checked (an answer stating a number, price, date or claim its
  sources lack is replaced by a fallback), bounded (input length, spend
  cap) and evaluated before release, injection attempts included; route
  the design through `llm-guardrails` and `llm-eval` and name both here.
- **Provider facts (external integrations).** A provider's rate limits,
  quotas, idempotency support, regions and retention come from its
  documentation, cited with a link in the section that uses them; the
  scaling arithmetic uses the documented number. "assumption:" is only for
  what the documentation does not say, and each one is an open question
  with an owner.

## Output contract

```
## HLD: <title>
Path: docs/design/<kebab-title>-hld.md   Status: Draft | Reviewed | Approved
Serves: REQ-..., US-..., <PREFIX>-<n>, ADR-...
Components: N   Failure rows: N (UNDEFINED cells: K)   Risks: R
Architecture set: tenets T, ADRs indexed A, conflicts C (open O), repos P (docs/architecture/)
Diagram: docs/architecture/diagrams/<Project>_SystemArchitecture_v<N>.svg (drawn | not drawn: run architecture-diagram)
Outside the standard stack: K (sign-offs pending: M)
Review: BLOCKER b (open x), MAJOR m, MINOR n, NIT t
Assumptions: K
- assumption: ...
ADRs needed: K
- ...
Open questions: K (owners assigned: N, missing: M)
Scaling numbers present: yes | no
Gate: <arch-check counts line> | not run (waiting for section 1)
Waiting for: agree section 1 (re-run with --continue) | settle conflict <n> | fix BLOCKER <title> | nothing
Next: new-repo <stack> <name> for each repo-plan entry
Revision: v<n> -> v<n+1>, sections changed C, ADRs superseded S, downstream D | v1 (new)
```

## Gotchas

- The author line and any delivering entity on the title page come from
  `.bearing/company.json` (`company-attribution`); when it is absent write
  "unattributed", never a guessed company.

- Never write section 2 onward before the yes on section 1. A wrong
  goal makes every later section waste.
- A design with no numbers in the scaling section is not finished.
  "Scales horizontally" is not a number.
- Do not choose the store, the queue or the auth model here. Those are
  ADRs (`adr`). Reference existing ones or say one is needed.
- No module layout, queries or class names in an HLD. That is `low-level-design`.
- A section with no risks has not been examined; "none" is not a risk
  list.
- The review is not optional and not self-graded: the critic wrote none
  of the design. Approved with an open BLOCKER or an open conflict fails
  the gate.
- A conflict settled by editing an Accepted ADR in place rewrites
  history; the fix is a superseding ADR named under What now has to
  change.
- No em dashes; short sentences; diagrams in mermaid so they diff.
