# high-level-design: inputs and their fallbacks

Read when a source is missing (Inputs): templates, standard stack, kit stacks, project name, delivering entity, existing system, task id, why this skill is not forked.

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

Step 1, in full:

1. Title from `$ARGUMENTS`; inputs from the sources under Inputs, each
printed as read or absent. Read the template (repository copy when
present, else `templates/HLD.md`). Collect the ids the design serves
(`REQ-nnn`, `US-nn-nnn`, `<PREFIX>-<n>`, `ADR-nnnn`) and put them at the top
of the document. Zero ids found: ask the one question under Inputs,
then continue with what it yields.
