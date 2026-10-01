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
- Eight subagents: `reviewer`, `verifier`, `security-auditor`, `explorer`,
  `test-writer`, `doc-writer`, `critic`, `prd-drafter`.
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

### Changed
- The handbook's four flows were reviewed against the skills and updated.
  Greenfield runs `estimate` after the backlog, then `architecture-diagram`
  after `high-level-design` (the HLD cannot be Approved without a drawn
  diagram), `data-model` and `openapi-spec` before `threat-model` (which
  needs the entry points and stored fields), the screen and model design
  before `low-level-design` (front-end components need the screens), and
  `tracker-sync` before planning; `/office-hours` runs only when the idea
  is still open, and model calls gain `llm-guardrails`. The feature flow
  decides what the change touches before it is planned, in one branch that
  now covers the data model (`data-model` then `db-migration`), a
  component's internals (`low-level-design`) and model calls. The bug fix
  flow writes a postmortem only when the bug reached users. The inherited
  flow draws the code as it runs (`architecture-diagram`) and audits the
  dependencies before the first change.
- `high-level-design` checks four more traps that an engineering review
  of a marketing website found after the HLD was approved: repeated
  requests (a request id under a unique constraint on every write
  endpoint), untrusted content (rendered as text, staff sessions on a
  separate origin), model output on a public path (grounded, checked,
  bounded, evaluated) and provider facts (limits, quotas and idempotency
  support from the provider's documentation, cited). The provider's
  idempotency key is now looked up, not left as an assumption, and the
  critic is given the Traps list to check.
- `prd` drafts a long brief in parallel: over 150 lines or 60 bullets, it
  splits the source at its headings into 3 to 6 ranges and forks one
  `prd-drafter` agent per range (read-only, Sonnet), then merges, dedupes
  and numbers the drafts itself. Sections, contradictions and the register
  stay in the main session. A 294-line website brief took about 7 minutes
  drafted serially.
- `prd` records what to build and stops reviewing the idea. Its register
  holds only points where the brief is unclear or contradicts itself
  about what the product does. Delivery questions (who builds, supplies,
  pays or signs off, the date and budget), engineering defaults, choices
  between named technologies and legal doubts are left out; a vague word
  is flagged and gets its acceptance in design. The critic runs only when
  asked. The PRD is vendor-neutral: it never names the company doing the
  work or assumes who the user is. On a 294-line website brief the
  register went from 54 entries to 13.
- `prd` resolves its open questions in the session (step 10) instead of
  leaving a register for someone to read. `scripts/register_answers.py
  rank` orders the open entries (assumptions first, then by how many
  statements each affects), the skill asks them four at a time as
  multiple choice with the assumed reading first, and `apply` confirms
  each answer with its date and source, keeps the old decision as
  history, records "ask the client" as a dated note, and rewrites the
  confirmation list and counts the backlog gate checks.
- `backlog` tasks take two more disciplines, `design` and `content`, for
  deliverables that are not code (brand guidelines, video, copy). A
  marketing website brief with launch collateral had 22 such tasks the
  gate refused under the five software disciplines.
- The REST tracker publishes documents. `brg-rest docs`, `doc-get` and
  `doc-put` (and `brg-tracker docs` and `doc-put` on rest) use the
  protocol's optional project documents API, and `tracker-sync docs` publishes the
  PRD as `prd`, the ADRs as `design` under one "Architecture decisions"
  parent, and the backlog, coverage, flows, estimate and decision log as
  `doc`. Each document carries an invisible source marker, so a rerun
  updates it in place (renamed or not) and an unchanged file writes
  nothing. `create` and `update` take `--document <id>`, so each story
  points at the PRD. The documents part of the REST protocol is optional;
  a server without it is named in one line and nothing is posted, and
  Jira, GitLab and GitHub skip with exit 3. Covered by
  `tests/contract/rest_documents.sh` against the fake tracker.

### Fixed
- `brg-tracker --help` printed three lines of code after its header (the
  range ran past the comment); it now stops at the last comment line.
- The guard refused a `for` loop that runs its own variable over literal
  words (`for p in python3 python3.12; do $p -V; done`) as "the program
  name is a variable that cannot be read". A list of literal words is now
  read and each value is checked as if written out; a list holding a
  variable, a substitution or a glob is still refused.
- `prd` stopped on a `.docx` brief and asked for a text export. It now
  converts `.docx` and `.odt` with `scripts/doc_to_text.py` (standard
  library, falls back to `unzip` when Python lacks zlib), reads PDFs
  directly, accepts a document attached to the message, and saves the
  input text under `docs/product/source/` so every `L<n>` source resolves.
  It asks for the product repository instead of writing `docs/product`
  into a folder that is not one.
