# Changelog

All notable changes to Bearing. Keep a Changelog format, semantic versions.

## [Unreleased]

First public release, under the MIT licence.

### Added
- Three plugins in one marketplace, laid out for the Claude Code plugin
  directory: `bearing` (required: the workflow skills, agents, hooks,
  scripts and templates), `bearing-backend` (go, python, node,
  data-pipeline, infra) and `bearing-apps` (react, nextjs, react-native,
  flutter, ios, android), under `plugins/`. Evals, tests and the sites stay
  outside every plugin. `bin/brg-kit-paths` finds the installed or
  checked-out plugins, so scaffold, adopt, the review checklists, the
  generators, the lints and the eval harness see every stack, and a
  missing stack plugin is named with the command that installs it.
  `make lint-plugin-size` holds each plugin under 512 files and 256 KiB a
  file; `make lint-version` covers every plugin and marketplace entry; the
  README lists every hook, what the guard blocks and every external fetch.
- 106 skills, one per job across the product lifecycle: discovery and
  planning (`prd`, `backlog`, `estimate`, `spike`, `explain-codebase`,
  `tech-debt`), decisions and architecture (`tech-decision`, `adr`,
  `high-level-design`, `low-level-design`, `architecture-diagram`,
  `data-model`, `threat-model`), design (`ux-flows`, `design-directions`,
  `design-system`, `screen-design`, `design-critique`), GenAI (`genai-design`,
  `prompt-registry`, `rag`, `llm-agent`, `llm-gateway`, `llm-guardrails`,
  `llm-eval`, `llm-fine-tuning`, `mcp-server`), build and verify
  (`start-task`, `test-cases`, `test-automation`, `test-run`, `test-heal`,
  `refactor`, `simplify-code`, `db-migration`, `definition-of-done`,
  `branch-review`), ship and operate (`merge-request`, `release`,
  `verify-deploy`, `runbook`, `incident`, `postmortem`, `on-call`), and
  conventions for thirteen stacks. Claude loads each skill from a plain request, or it can be called
  directly as `/bearing:<name>`.
- `simplify-code`: reads every unit in scope (a path, a branch's diff or
  the repository), decides keep, cut, inline or merge for each with its
  evidence, and deletes what a change does not need with tests green after
  every step; a cut that would change behaviour is proposed, not made.
- `autopilot`: an unattended run from one statement to a prepared merge
  request, with a gate per stage; it never pushes. A headless run hands
  the smoke test of the shipped app to the launcher, which runs it outside
  the sandbox and resumes the session with the verdict.
- Seven subagents: `reviewer`, `verifier`, `security-auditor`, `explorer`,
  `test-writer`, `doc-writer`, `critic`.
- One guard script (`bin/brg-guard`) behind every hook: the agent never
  pushes, merges, tags, publishes or deploys, and never reads secret files.
- Repository templates and a scaffold for thirteen stacks, an adopt path
  for existing repositories, and adapters for Cursor, Codex, Gemini CLI,
  Copilot, OpenCode, Windsurf, Cline, Zed and Kiro.
- Tracker adapters for Jira, GitLab, GitHub, a documented REST protocol
  any service can implement, and none.
- A skill eval harness (`bin/skill-evals.py`): each skill run blind
  against no skill, with expectations a grader checks from the transcript
  and the repository the run left.
- The handbook site and the developer guide, both generated from the
  repository.
