# autopilot: stage skills and scope

Read when loading a stage skill the Skill tool refuses, or when deciding lean or full scope (Inputs).

- the stage skills: loaded with the Skill tool, or, for a command-only skill
  the Skill tool refuses (most Bearing skills: new-repo, prd,
  data-model, openapi-spec, deployment-architecture, ux-flows,
  design-system, screen-design, design-critique, test-cases,
  test-automation, start-task, merge-request and others), read from
  `${CLAUDE_PLUGIN_ROOT}/skills/<name>/SKILL.md` and followed the same way.
  Every skill `next` names is run, each in turn; writing its document
  freehand instead is how the first run skipped the data model, the API
  contract and every design skill while its gate still passed.
- scope: `lean` or `full`, printed by `status` and by each gate. Lean is a
  change to a repository that already had code, or a new product with
  no UI, data, API or deployment (a CLI, a library). Full is everything
  else, and a change that adds a service, a store, an external
  integration or a new UI area (`profile --scope full`, with the reason).
  In lean scope the stage skills are followed for their method, but
  the run writes only what a reviewer of this change reads: the PRD's
  REQ lines for this change, its stories and coverage, one design note
  (`docs/design/<name>.md`: what changes, where, the existing rules it
  follows, what it leaves alone), the risk register and case table, the
  report. No C4 set, tenets, repo plan, HLD, test plan, scenarios, step
  tables, import or question logs, user flows or progress files: a
  12-line search command once came with 25 documents and 1,145 lines,
  and the reviewer failed it for that alone. The documents are sized to
  the diff, not to the template.
