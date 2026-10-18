# Changelog

All notable changes to Bearing. Keep a Changelog format, semantic versions.

## [Unreleased]

### Added
- impeccable is pinned (`plugins/bearing/bin/pinned-packs.txt`) and installed
  in the standard profile; `doctor` reports it, and `install` takes
  `--skip-impeccable` (held on the full profile too).
- design-directions: one impeccable direction round when impeccable is
  installed and the run is attended, recorded in `approved.json` as the
  locked `direction`. Without impeccable it prints `impeccable not
  installed` once and runs the three-variant path as before.
- design-system derives `tokens.json` from the `DESIGN.md` frontmatter when
  it has tokens, else from the approved direction, and records which
  (`source: design-md | approved-direction`) with the hash of that source.
  The hash check is the `--sync` and `--hash` modes of
  `design-system/templates/design-lint.sh`; the make target is
  `tokens-sync`.
- screen-design: an impeccable harden and polish pass before the state and
  contrast gates (one fix, then revert on a failing gate).
- screen-design writes `docs/design/screens/<feature>/data-needs.md` (per
  screen: fields, actions with outcomes, states with a server condition,
  each marked exists or new; fields have ids F-nn and actions A-nn, other
  shapes fail) and checks it with
  `states_check.py --needs <data-needs.md> --flows <flows.md>`, which
  prints `data-needs: N screens, N fields, N actions (...), N outcomes, N
  states, N problems` and fails on zero.
- openapi-spec derives operations from the screens' data needs (`x-data-needs`
  on each operation) and checks them with
  `api_doc.py needs --spec F --needs F [F ...]`, which prints `data needs: ...`
  and fails on zero actions. data-model checks its columns against the same
  files with `model_check.py --needs`.
- design-critique has a counted task cost category (5%), from the flows'
  task paths and the confirmations on reversible actions, and takes
  impeccable `audit` findings.
- ux-flows: a `## Task paths` section, one row per user task with its kind,
  path and counts, held to a budget (primary 3 screens and 6 interactions,
  secondary 5 and 10, overridable in `.bearing/config.json`) by
  `flows_check.py`, which prints a `task paths:` line.
- Eval cases for the task budget, written data needs, operations from data
  needs, and the impeccable fallback and unattended runs.

### Changed
- `flows_check.py` requires `## Task paths`: a flows file without it now
  fails. Existing repositories add the section to each flows file (see
  Notes for existing repositories).
- The greenfield and feature flows put screens before the data model, the
  API contract and the threat model.
- `autopilot` gains a `contract` stage after `ux`. A feature with screens
  needs its `data-needs.md` when the run has a UI and data or an API. A
  run saved before this change, with `design` done and a later stage (`lld`
  or after) done, has `contract` carried as done when it is loaded, with a
  note. The newest flows file is
  chosen by version number.
- design-critique weights: twelve categories, typography 10%, task cost 5%.
- Data-needs ids are unique across the product, not per file: a new
  feature numbers its F- and A- ids after the highest in the other
  features' files. `api_doc.py needs` and `model_check.py --needs` fail on
  an id in two features' files, naming both and saying to renumber.
- `states_check.py --needs` fails on a screen that shows server data (a
  `server` field or a server condition) with no server action: the read
  that loads it is listed as an action, marked `exists` when the API has it.
- The autopilot contract gate runs `api_doc.py needs` through uv with the
  pinned PyYAML (`--with pyyaml==6.0.3`) when uv is installed, so a YAML
  `api/openapi.yaml` is read; with neither uv nor PyYAML it fails naming
  the dependency.
- autopilot passes `--unattended` to screen-design and design-critique, and
  design-critique also reads `brg-config get noninteractive --user`, so an
  unattended review never runs impeccable `critique`.

### Notes for existing repositories
- Add a `## Task paths` table to every `docs/design/flows/*/flows.md`
  (columns Task, Story, Kind, Entry, Path, Screens, Interactions, Over; the
  `ux-flows` skill's `references/task-paths.md` has the format), then run
  `flows_check.py`. Without it the flows check fails.
- A `data-needs.md` written by hand uses ids F-nn for fields and A-nn for
  actions; `states_check.py --needs` rejects other shapes. Renumber any id
  that repeats another feature's, and add the read action to each screen
  that shows server data.

### Noted
- impeccable `critique` asks a question at its close, so an unattended run
  (`BEARING_NONINTERACTIVE`, `BEARING_AUTOPILOT`, `--unattended`) runs only
  `audit`; design-directions skips the impeccable round when unattended and
  takes its own fallback.
- Plugin size: `bearing` is at 511 files; the cap is under 512.

## [0.8.0] - 2026-10-17

### Added
- Scoped Stop gate: a `check-changed` make target in all 13 stack
  templates checks only what the session changed (Go: the changed
  packages; Python and JavaScript: the changed files and their related
  tests). The Stop gate asks for `make check-changed` where the Makefile
  has it. The full `make check` is unchanged at `definition-of-done` and in
  the pre-push hook. `brg-changed` lists the changed files. A session
  that changed no file of the stack's kind (a README, a YAML file) passes
  it; a skipped gate (Go without golangci-lint) does not.
- Timing: the formatter is timed, and `brg-guard stats` and
  `brg-doctor --timing` show the median and p90 of every gate and hook
  step.
- Workspace trust check in `doctor` and `autopilot`: an untrusted workspace
  is reported (trust on a parent folder counts), and `autopilot` stops
  before it would wait on a permission prompt.
- Sessions: a skill timeline recorded by a PreToolUse Skill hook; a
  checkpoint written on Stop and before compaction; resume at startup that
  prints the checkpoint and the next flow step (from the generated
  `plugins/bearing/bin/flow-steps.tsv`), quiet on trunk with no history;
  SessionEnd refreshes `docs/progress/<ID>.md` without overwriting a
  person's Next or dropping a line they added; resume offers the state
  file's Next before the flow step; `start-task` reads the task id from
  the branch. A non-interactive session (`BEARING_NONINTERACTIVE=1`, or
  `BEARING_AUTOPILOT=1`, which `brg-autopilot` sets) is asked nothing at
  startup.
- Updates: a newer Bearing tag is offered once a day (cached, 3 s budget,
  6 h negative cache, hardened against option injection) with Upgrade,
  Remind me tomorrow or Skip this version.
- Learning, opt-in and local only: lessons from gate blocks and reruns are
  written to `learnings.jsonl` beside `bearing.env`, paths reduced, and read
  back for the next step. The `learn` skill manages them; `learn propose`
  drafts a redacted issue and prints the `gh` command for the engineer.
  Nothing leaves the machine.
- Console contract: `plugins/bearing/references/console.md` defines how
  skills ask; `brg-config` keeps project answers (`.bearing/config.json`)
  and user answers (`bearing.env`); `workflow` with no argument opens a
  menu of the next two or three skills; 31 skills ask through
  AskUserQuestion; `lint-questions` in `make check` finds skills that ask
  in prose.
- `lint-skill-size`: a SKILL.md is 200 lines or fewer. Eight skills keep
  per-run rules over that and are listed with a reason and a ceiling in
  `bin/lint-skill-size.allow`.

### Changed
- Skills over 200 lines keep the steps in SKILL.md and move detail to
  `references/`. `lint-tools` now reads each skill's `references/` and
  flags code spans wrapped across lines.
- The `verifier`, `critic` and `security-auditor` agents default to
  `sonnet`; the calling skill asks for `opus` on Critical findings, VAPT
  and graded HLD reviews.
- Resume is computed in one pass.
- Some commands now prompt by design instead of being granted: env-prefixed
  runs in `test-run`, the throwaway cleanup `rm` in `spike`, and `git -C`
  in `harness-setup`. They are recorded as `prompts:` rows in
  `bin/lint-skill-tools.allow`.

### Fixed
- The Python, Python CLI, data-pipeline and Flutter templates' `check-changed`
  parses under bash 3.2 (macOS `/bin/bash`): `case` patterns inside `$(...)`
  are parenthesised.
- The Go service template requires `golang.org/x/net` v0.60.0
  (GO-2026-6611, GO-2026-6612, GO-2026-6617).
- The update prompt reads its changelog lines without a pipe that can
  close early, so no stray warning reaches the session.

### Notes for existing repositories
- Add `check-changed` by hand: copy the `CHANGED` variable and the
  `check-changed` target from the stack template
  (bearing-backend/bearing-apps skills/<stack>/templates/Makefile).
  `onboard-repo` does not add them. Until then the Stop gate behaves as in
  0.7.0 and asks for the full `make check`.

## [0.7.0] - 2026-10-02

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
- `autopilot` runs a product whose documents came before its code. A
  repository holding only documents (a PRD, ADRs, an HLD) is a new
  product in full scope, not a change; `brg-scaffold` merges the stack in
  beside the documents without overwriting one; and a repo plan entry
  with `"path": "."` places the code in that repository (`arch_check`
  accepts its own git path). The branch stage now comes right after the
  repo stage, so no stage writes documents on the trunk; low-level design
  moved from the design stage to a new `lld` stage after the screens (the
  handbook's order, since a front-end component's design names its
  screens); the design gate requires a threat model; and `profile --llm`
  adds `genai-design` to design and `llm-guardrails` and `llm-eval` to
  test automation. A run started before a stage existed gets it as
  pending. Found by running a marketing website's autopilot after its
  PRD, backlog, ADRs and HLD were already committed.
- The Next.js stack (`next-app`) gets the design gallery at `/__design`
  that screen-design and design-critique read on react-web: screens as
  `*.screen.tsx`, a registry written by `make design-registry` (Next.js has
  no `import.meta.glob`) and checked by `make design-registry-check`, the
  33 shadcn components, an example screen, a theme script that sets dark
  before the first paint, dark that follows `data-theme` as well as the
  class, pages that own their width, and a test setup with a
  `ResizeObserver` stand-in for Radix (react-web too).
- `deployment-architecture` maps its template onto managed platforms
  (Vercel, Netlify, Cloudflare, Supabase): functions for workloads,
  per-request instances for replicas, the edge for ingress.
- `ux-flows` says how to handle a product designed contract first (the
  API contract's error codes are the rejections), a site with no visitor
  accounts, several packages sharing one id space, site-wide stories and
  page chrome.
- `openapi-spec` extracts Next.js App Router route handlers, and warns
  that Redocly accepts flow-map values PyYAML (and so `api_doc.py`)
  rejects.
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
- `CLAUDE.md` from the scaffold said `Git host: gitlab | github | both`
  literally; `brg-scaffold` and `brg-adopt` now fill in the chosen host.
- `apply_check.sh` proved a schema that creates the vector extension
  against plain `postgres:16`, which has no pgvector; it now uses
  `pgvector/pgvector:pg16` for such a schema.
- `flows_check.py` took a page named "confirmation" for a dialog, let a
  second error row overwrite the first (so a labelled `error: code` row
  failed), and did not notice two packages using one screen id.
- `evidence.py` named every shot of one gallery screen the same, so three
  design directions overwrote each other's screenshots; the query keys
  that change the picture (`state`, `variant`) now name the file. The
  galleries follow the system theme when no `?theme` is given, so the
  Chrome fallback's dark shots are dark.
- The Next.js gallery's screen route read `params` outside Suspense,
  which Cache Components refuses.
- `design-system`'s `system_page.py` takes `--fonts-css` or
  `--google-fonts` and fetches no font from an outside host by default;
  design-lint skips the stylesheet that defines the tokens; the
  validator `jsonschema==4.25.1` is pinned and named in the README; the
  schema documents opaque composite tokens; the Tailwind 4 binding adds a
  `--text` size for any token size the default scale lacks.
- The pre-commit hook format-checks YAML and `.mjs` files and skips
  symlinks, which prettier refuses on the command line.
- `gallery_check` needs one state per repeated row and normalises colons
  and brackets in state names; the scaffold's example screen is S-00,
  noted and never failed; the Next.js template ignores its generated
  registry in prettier and eslint, and `.mts` files skip type-aware lint.
- The slider in the React and Next.js templates takes `thumbLabels`, so
  each thumb of a range has its own accessible name.
- vitest in the React and Next.js templates waits 15 seconds a test: a
  full suite under parallel load timed out on the default 5.
- The `nextjs` skill says how to build when the app owns its data
  (Supabase or a driver): route handlers on a typed server layer, the
  migrations tested by a `make test-db` that fails on zero files.
- `cases_check` reads a case's withdrawal from its Status line, splits
  oracles outside quotes, and compares the plan's quote without its
  problem count.
- The edit hook's `check-file` reports a test written before its module
  as the expected red, not a wall of unsafe-call errors.
- `autopilot`'s build gate also requires `make build` after the last
  change when the Makefile records a build pass, which the Next.js and
  React templates now do: a page that cannot prerender passed every
  check and failed only the build. The skill says how a build split
  across parallel subagents shares one local database.
- The format and lint file lists in the Next.js, React and Node templates
  skip a file deleted but not yet staged (prettier and eslint failed on the
  missing path) and symlinks; the Next.js and React templates do not lint
  `public/` and fail `make lighthouse` on an empty URL list; the GitHub
  workflows no longer name a `.gitlab-ci.yml` that a GitHub scaffold removes.
- `ref_check` matches a name the source builds in a template literal,
  reads Maestro `id:` and `tapOn:` keys only in YAML flows (a fixture's
  `id:` field was taken for a test id), and fails when a directory is
  passed where a test file goes. `test-automation` says that a case whose
  feature was never built is a finding that blocks the stage, not a test
  against an invented path.
- `llm-eval` names the lint and `server-only` traps of a TypeScript
  runner; `llm-guardrails` lets a feature that stores no personal data
  skip redaction with the reason recorded, and tests checks inside an
  entry point through that entry point.
- `api_doc.py` names each operation's `operationId` beside what it
  does, so API.md can be checked against the contract by id.
- The test-automation gate in `brg-autopilot` reads past binary fixtures
  (an audio file beside the e2e specs) instead of crashing.
- `branch-review` runs the project check in a copy that is its own git
  repository with the dependencies linked, so file-list gates no longer
  see the enclosing repository and check zero files, and tells gstack
  `/review` to keep to the committed range. `brg-checklists` gives CI
  workflows, Dockerfiles and compose files the infra checklist, which
  gains a CI workflows section from the 7 Hills review.
- `make build` in the Next.js and React templates runs the bundle budget
  before it records a pass, so autopilot's build gate catches an app that
  outgrew it (7 Hills shipped 620 KB against 350 and only CI would have
  said so).
- Tests run on macOS again: `wc -l` counts are trimmed, `paste` reads
  standard input with `-`, and in-place edits use `perl -pi` with quoted
  patterns instead of GNU-only `sed -i`. The React template's test setup
  wraps a line prettier refused.
- `design-critique` measures a framework gallery: `snapshot.mjs` renders each
  page in Chrome through the app's Playwright, light and dark, and writes
  static HTML and CSS of the computed colours and focus rings for
  `pairs.py`, which cannot resolve Tailwind v4's `@layer` output. The Chrome
  fallback in `evidence.py` waits on virtual time so a screenshot catches
  the hydrated page and an open dialog, and both design skills point at
  `localhost`, since a Next.js dev server never hydrates a page loaded by IP.
- The Next.js template has `make smoke`: it starts the standalone build with
  `.env.local` loaded (never printed), drives `.scratch/smoke-plan-<id>.txt`
  or the health probe and home page, and writes the evidence file the
  autopilot dod gate reads; the plan runner alone could only start stacks
  with `make up` or compose. Its bundle budget leaves out the nomodule
  polyfill file, which no module browser downloads.
- The `nextjs` guidelines record what the 7 Hills smoke found on the built
  server and no unit test caught: under Cache Components `notFound()` after
  the shell streams answers 200, a status on a proxy rewrite is ignored, an
  app with several root layouts needs `global-not-found`, and a random
  value read in a client render leaves a hole in the prerendered shell. The
  template's smoke fails on a render error the server logs.
- `red_proof.sh` keeps toolchain files at HEAD (it used to revert
  package.json on a branch whose base had no app, so pnpm failed and the
  script printed "proven"), restores a deleted file's folder, treats
  "Cannot find package", "is not a function" and pnpm errors as the wrong
  reason, and takes `--commit <sha>` to prove one fix of a long branch.
  `prose_check` reads "Generated with" as a trailer only at the start of a
  line, so content saying how audio was made is not flagged.
- The Bearing repository gates its own pushes: `make gate` runs `make
  check` and `make ci-bash32` and records the commit it passed on, and
  the pre-push hook `make hooks` installs lets that commit through (a
  gate run inside the hook outlasted the SSH connection to GitHub). `make
  ci-bash32` is the bash32 CI job in the same `bash:3.2` image, now one script
  (`tests/ci-bash32.sh`) that CI and the target share. `make check` gains
  `lint-portable`, which rejects commands a CI image lacks or runs
  differently (`perl`, `sed -i`, `grep -P`, `readlink -f`, `date -d`).
  Two pushes on 2 Oct failed CI on exactly these after `make check` passed.
  Tests edit fixtures with `replace_in` from `tests/lib/assert.sh`.
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
