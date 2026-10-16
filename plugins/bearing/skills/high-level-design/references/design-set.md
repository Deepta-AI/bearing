# high-level-design: sourcing, repos, tenets, reconciliation, summary

Read at steps 4 to 8: sourcing claims, the standard stack and repo plan, tenets, reconciling ADRs, the summary and components.

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
