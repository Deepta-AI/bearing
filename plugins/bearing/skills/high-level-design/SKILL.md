---
name: high-level-design
description: 'Writes a High Level Design (HLD): goals and non-goals agreed first, then architecture, data, interfaces, failure modes, rollout. Use when asked for an "HLD", "system design" or "an architecture overview".'
argument-hint: "<title> [path to PRD or notes] [--continue after the goal is agreed]"
allowed-tools: Read, Write, Grep, Glob, Skill, Agent, AskUserQuestion, Bash(python3 *skills/high-level-design/scripts/arch_check.py*), Bash(bash *bin/brg-kit-paths*)
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
- Templates, standard stack, kit stacks, project name, delivering entity,
  existing system, task id: each with its fallback. Detail:
  references/inputs.md
- This skill runs in the main conversation, not forked: it needs the Skill
  tool, the Agent tool and the user's yes on section 1. Its only shell is
  the gate script.

## Steps

**Revising.** When the output file already exists, this run is a revision:
read `${CLAUDE_PLUGIN_ROOT}/skills/adr/references/revision-protocol.md`
and follow it. Detail: references/revising.md

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
   present, else `templates/HLD.md`). Collect the ids the design serves and put
   them at the top of the document. Detail: references/inputs.md
2. Without `--continue`: write section 1, goal and non-goals, into
   `docs/design/<kebab-title>-hld.md`. Three sentences for the goal, a
   list for the non-goals. Ask with AskUserQuestion as `${CLAUDE_PLUGIN_ROOT}/references/console.md` says
   ("agree the goal and non-goals?": yes, changes, stop here) and wait. On a yes, go on; on changes, rewrite section 1
   and ask again; when the user stops here, print the contract with
   `Waiting for: agree section 1`. With `--continue` (a later session):
   read section 1 from the file as agreed and go on. Never draft section
   2 onward before the yes.
3. Fill sections 2 to 12 in template order. Detail: references/sections-2-to-12.md
4. Source every claim. Grep the code for each component, route, table and
   queue you name. Detail: references/design-set.md
5. Standard stack and repos: section 13 and `docs/architecture/repo-plan.json`.
   Detail: references/design-set.md
6. Tenets: `docs/architecture/tenets.md`, five to eight checkable rules.
   Detail: references/design-set.md
7. Reconcile every ADR, criterion and the data model into
   `docs/architecture/decisions.md`. Detail: references/design-set.md
8. Summary and components, written last. Detail: references/design-set.md
9. Review, mandatory. Fork `critic` (Agent tool) in graded mode (pass model: "opus" on the Agent call), and write
   its findings verbatim under section 16. Detail: references/review-and-gate.md
10. Open questions and assumptions (section 17), then run `arch_check.py`
    until `Gate: passed`. Detail: references/review-and-gate.md

## Traps

What separates a design that survives review from one that reads well.
Check each against the draft before step 9; the critic in step 9 is given
the list too. Detail: references/traps.md

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
