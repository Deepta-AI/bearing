# Changelog

All notable changes to Bearing. Keep a Changelog format, semantic versions.

## [Unreleased]

### Added
- `make evals-weekly`: trigger-eval and harness-eval, then a row in the
  tracked `evals/scoreboard.jsonl` (`bin/eval-scoreboard.py`) compared with
  the last one. Fails on zero cases or a regression (recall or false
  triggers moved by more than 5 points, a harness scenario falling) and
  keeps the row. `make evals-timer` prints systemd user units for a weekly
  run and installs nothing.
- `make skill-tune` (`bin/skill-tune.py`): propose an edit to one skill
  from the expectations it last failed, measure the edited copy beside
  the skill as it is, and keep it as a patch only if with_skill gains 10
  points without a smaller margin over no skill. Nothing in the
  repository changes.
- `make claude-drift` (`bin/claude-code-drift.py`): what Claude Code
  added since `docs/claude-code-surface.json` (first record: 2.1.287, 31
  hook events, Bearing uses 7) and any hook event or CLI flag Bearing
  uses that is gone, which fails the run.
- `make pin-refresh` (`bin/pin-refresh.py`): how far each pinned pack is
  behind upstream, with the files changed under the pinned path and a
  flag on a changed SKILL.md and on a link under the pinned path (the
  installer would copy it as a link). First run: 80 pins, 27 behind.
- Hooks on four more Claude Code events: `StopFailure` writes the
  checkpoint and logs the API error type, so the next session resumes;
  `PostToolUseFailure` and `PermissionDenied` log the tool name (never its
  input, error or reason) to `gates.log` for `brg-guard stats`;
  `SubagentStop` sends `bearing:verifier`, `reviewer` or
  `security-auditor` back once when its report misses its output
  contract, and never twice.
- `make eval-audit` (`bin/eval-audit.py`): every expectation sorted by
  whether it tells a run with the skill from one without, from all graded
  runs on the machine: discriminating, no signal, never passes, favours no
  skill, and flagged by a grader. First audit, adr: 21 expectations, only
  3 discriminating, 12 with no signal.
- Held-out cases: `"held_out": true` in evals.json keeps a case's failures
  from skill-tune's proposer (which now edits a bare copy of the skill and
  cannot read any evals folder); an edit whose held-out cases fall is
  rejected. adr has the first, case 3 (a proposed decision, nothing
  decided).
- Evals run in parallel: `skill-evals-run` measures three skills at once
  (`--parallel-skills`) under one cap on open sessions (`-j`, default 6),
  `skill-tune` measures the copy and the skill as it is at the same time,
  and `evals-weekly` runs trigger-eval eight at a time.
- `skill-evals.py alternative <skill> <invoke>`: pair a Bearing skill
  with an installed rival from another pack, kept in the private results
  file only; `skill-evals-run` then measures it in three arms.
- `bin/skill-evals-run.py`: skill-evals with no one at the keyboard.
  Executor and grader sessions run through `claude -p` in the Bash
  sandbox (localhost only, no Skill tool, no settings) over a rotating
  set of skills (changed since last measured, then never measured, then
  oldest; five a week by default). `make evals-weekly` runs it and the
  scoreboard records each skill's pass rate with and without it; a
  with_skill drop of more than 10 points since the skill's last
  measurement fails the run. `bin/skill-evals.py` takes
  `BRG_SKILL_EVALS_WS` and `BRG_SKILL_EVALS_PRIVATE`.

### Changed
- The handbook and the developer guide are redesigned as one dark-first
  system in the spirit of Linear: tokens in `docs/design/tokens.json`
  (bound in `ui/tokens.css`, contrast measured), Geist type, one indigo
  accent, shared tabs, segmented controls, tiles and step cards, rebuilt
  home pages and rewritten page copy. Dark is the default; the toggle pins
  light.
- The sites describe each skill from `docs/skill-summaries.json`, written
  for readers, instead of the trigger-oriented frontmatter description;
  `bin/gen-guide.py` fails when a skill has no summary or a summary names
  no skill.

- Five pinned packs moved to their upstream heads after reading each
  diff (`make pin-refresh`): getsentry `gha-security-review`, the six
  `android/skills` rows, grafana `k6`, the four addyosmani skills and
  dash0 `otel-instrumentation`. Expo, `create-prd`, `swiftui-pro` and
  the large packs stay where they were for the maintainer to decide.

### Fixed
- The skill-evals executor prompt forced every decision record to
  Proposed, so a case whose request says "it is accepted" could never
  pass; a run now records as decided what the request says was decided,
  and nothing it chose itself. adr's two cases no longer penalise the
  decisions index the skill creates on purpose.
- A relative `BRG_SKILL_EVALS_WS` broke `measure` (the aggregator runs in
  its own directory); the workspace and results paths are made absolute.
- The skill-evals executors could not write `transcript.md` to their run
  folder (the sandbox kept it read-only), so the first real measurement
  failed every run; each executor now gets its run folder, and only it,
  as writable, and its JSON result is kept as `session.json`.
- A push from a linked worktree no longer lets the gate write into the
  main repository. Git exports `GIT_DIR` and `GIT_INDEX_FILE` to a hook
  from a worktree; the pre-push gate inherited them, so every test that
  ran git in a temp folder created tags, branches, commits and config in
  the real clone. Bearing's own `.githooks/pre-push` and the template
  `pre-push` now run the gate without them, and `tests/lib/assert.sh`
  drops them for every test (`tests/unit/repo_pre_push.sh`).
- The React template pins `vite` 7.3.7, clearing GHSA-587h-7wmj-h5pm
  (high, `launch-editor`) that failed `make vuln` in a new React repository
  and the `scaffold (react-web)` CI job.
- New Go scaffolds pin `go 1.26.10`, so their CI (`go-version-file: go.mod`)
  installs a Go with GO-2026-6809 (`crypto/x509`) fixed, and Bearing's own
  CI sets up Go with `check-latest`, so the `scaffold (go-api)` job's
  `govulncheck` no longer reports the runner's cached 1.26.9.

## [0.9.0] - 2026-10-21

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
- Quality phases in every flow. The feature flow has a Test phase
  (`test-run --changed`, then `/qa` for a user interface or `load-test` at
  smoke for a hot path) and a Review phase (`branch-review`, then `/cso`
  when the change touches auth, payments, personal data or external input)
  before Verify. The bug fix flow runs `test-run --changed` after the fix,
  then the review and the security branch, then definition of done.
  Greenfield gains a "Test and review the release" phase before the first
  release: the full regression (`test-run --suite all,matrix`), a review of
  the whole release range, and optional `load-test` and
  `resilience-testing` drills.
- `brg-changed --layers [--base <ref>]` maps a diff to test layers and
  prints `brg-changed: <N> files, layers: ...`; it exits 1 on zero files
  and outside a repository, with its error line on stderr.
- test-run has two scopes: `--changed` runs the layers the diff touches,
  and a full run (`--except <suites>`) runs every suite present. Every run
  writes `.scratch/test-run/<branch>-<scope>.json` (the branch with `/` as
  `_`), whose `selection` is null when no `--suite`, `--tag`, `--tc` or
  `--except` narrowed it; a filtered run writes `<branch>-filtered.json`
  instead (`--except unit` alone still writes `-full.json`), so one test
  never replaces the full run; a full run also writes `docs/testing/reports/<date>-<branch>.md`
  and `.json`. A suite runs its Makefile target (`test`,
  `test-integration`, `test-e2e`, `test-ui`, `test-visual`,
  `test-e2e-matrix`) when one exists.
- branch-review writes `.scratch/review/<slug>/verdict.txt` (the reviewed
  range, the head sha, the file count, the verdict, the findings and the
  blocking finding numbers). An unattended run uses the bearing reviewer,
  never gstack `/review`, which can ask a question.
- Opt-in push of the task branch. `BEARING_AUTO_PUSH` in the personal
  `bearing.env` lists full push URLs (ssh, scp-style or https); it is empty
  by default, and then Bearing never pushes. `brg-push check` names each of
  its eight conditions, `brg-push request` records the request after the
  gate, and `brg-push status` prints the last result. The Stop hook pushes
  the current task branch from a fresh clone to the listed URL whose host
  and path match origin's: never main, master, develop, a release branch
  or a tag, never forced, never merged, and never from the working tree.
  CI checks the pushed branch.
- The `site` flow for landing pages and marketing sites: a page brief from
  brainstorming instead of a PRD and backlog, the Next.js stack
  (`next-app`, the `nextjs` skill), optional design direction and design
  system steps, then screens, the build, a scoped test run, the checks
  and the review.
  `start-task --flow site` records `"flow": "site"` in
  `.bearing/config.json` in the new task branch, so later sessions in the
  repository follow the site flow (a fix branch still follows bugfix).
- Task sets: one task across repositories. `start-task --repos <list>`
  gives every member the same branch, settles the merge order and prints
  the line to start each sibling (with `--type`); each progress file gets
  a `## Repos` section; `progress.py set --task <ID>` reports every
  member's state and the merge order; the rules are in
  `references/task-set.md`. One session per repository.
- definition-of-done has a task-set item: `n/a` without `## Repos`, else
  judged from `progress.py set`.
- `brg-session next-step` (and so `resume`) skips a branch step whose
  condition already holds: `new-repo` once the repository has a commit,
  `design-system` once `docs/design/tokens.json` exists.
  `flow-steps.tsv` gains a fourth column, `step` or `branch`.
- Eval cases for the opt-in push request with and without the opt-in, a
  two-repository task set and a bugfix sibling's type, the site flow
  recorded at start, and the workflow skill's next step in a site
  repository.

- `bearing-genai`, a fourth plugin installed by default, holds the 12
  GenAI and ML skills that were in `bearing` plus two new ones, 14 in all.
  `install.sh`, `brg-doctor`, `upgrade-tools` and autopilot know it;
  autopilot's `llm` profile refuses to start when `genai-design` is not
  installed.
- model-routing picks the cheapest model or cascade per LLM feature that
  still passes its eval, from measured scores and costs, any provider.
  Each cascade leg carries its own effort, `max_tokens` and timeout.
- dataset-generation makes eval, training or preference data from a real
  seed: taxonomy, generation, dedupe, a contamination check against the
  golden set, a person's audit and a datasheet. Unattended, it stops
  before anything is promoted.
- llm-eval reports confidence intervals, compares two versions on paired
  cases, and calibrates a judge against at least 30 person-labelled items
  (kappa at least 0.6) before its scores gate anything; `eval_stats.py` is
  vendored into `evals/tools/` with a source, version and sha256 header.
- A GenAI task flow from genai-design through the eval baseline, the build
  branch, prompts, the gateway, model routing, guardrails, tests and the
  eval gate to the merge request. The "Calls to a model" options in the
  greenfield and feature flows link to it, and `brg-session next-step`
  follows it on a non-bugfix branch that ran genai-design.
- `lint-model-ids` (part of `make check`) holds every Claude model id under
  `plugins/` to `bin/model-ids.txt`: defaults `claude-opus-5-5`,
  `claude-sonnet-5-5` and `claude-haiku-4-5`.

### Changed
- Hooks resolve tools on a fixed PATH, which now also holds the Linuxbrew
  and Nix directories (`/home/linuxbrew/.linuxbrew/bin`,
  `/run/current-system/sw/bin`, `/nix/var/nix/profiles/default/bin`); each
  hook script starts the next with `"$BASH"` from its own directory (no
  PATH lookup, no `dirname`) and exits 2 when that fails, so the Bash guard
  blocks rather than exiting 127. `brg-doctor` checks jq, python3, git and
  bash on that PATH and prints the fix, and the settings template denies
  Edit and Write on `/opt/homebrew/bin`, `/usr/local/bin` and the Linuxbrew
  bin.
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
- `autopilot` gains a `test_run` stage after `test_automation`: a scoped
  run of HEAD with at least one suite run and 0 failed, or a docs-only diff
  (0 layers, files above 0). A suite not run passes only when a
  `test_run.<suite>` decision whose choice starts "left to CI" records it.
- The autopilot review gate reads the newest `verdict.txt`: 0 files never
  passes, the reviewed sha must be an ancestor of HEAD made on this branch
  (past its merge base with the default branch, so a verdict left from a
  merged branch fails), and a "not ready to
  merge" verdict needs each blocking finding listed as `<n> <sha>` in
  `.scratch/review/<slug>/fixed.txt`, a commit after the reviewed one. A
  review folder with no `verdict.txt` no longer passes.
- definition-of-done item 14 runs every suite beyond unit in full on HEAD
  (`test-run --except unit`), or reuses a full run whose sha differs from
  HEAD only by `docs/testing/reports/`. A suite it cannot run is handed to
  CI: attended, the user is asked; unattended, only when a CI job runs the
  suite, recorded with
  `brg-autopilot decision test_run.<suite> "left to CI job <job>" ...`.
  The autopilot dod gate needs `.scratch/test-run/<branch>-full.json` from
  an unfiltered run (`selection` null or `{"except": ["unit"]}`) with more
  than 0 tests. Autopilot calls `branch-review --unattended` and
  `definition-of-done --unattended`.
- Hooks run outside the sandbox while the working tree, `.git/config` and
  the agent's environment are the agent's to write, so no hook runs a
  program the repository names (a Makefile target, a working-tree binary,
  a prettier plugin, or a git hook, filter, fsmonitor, pager, external
  diff, credential helper, askPass or ssh command from its git config),
  and no hook writes through a link the agent planted:
  - The PostToolUse edit hook runs only an allow-listed formatter (gofmt,
    prettier, ruff format, ktlint, swiftformat, terraform fmt, shfmt) taken
    from fixed system directories (`/opt/homebrew/bin`, `/usr/local/bin`,
    `/usr/local/go/bin`, `/usr/bin`, `/bin`, `~/.local/bin`, `~/go/bin`),
    never `node_modules/.bin`, the inherited PATH or `uv run`, in a cleared
    environment. Prettier runs only when the config that applies is
    `.prettierrc.json` or a `package.json` `prettier` object, parsed as
    JSON with `python3 -I`, every key a plain formatting option (overrides
    of those, a built-in parser name); any other form (`.prettierrc`, YAML,
    TOML, JSON5, JS, TS, `package.yaml`) or key, an escaped one included,
    means it says it did not run. A linked file is not formatted.
  - `brg-guard check-file` no longer runs `make check-file`, eslint, go vet
    or any linter. It prints one line saying the hook ran no check and
    naming `make check-file FILE=<path>` to run in the session, and never
    blocks.
  - Every gates.log append (the guard, brg-session, brg-learn,
    brg-update-check, session-end.sh) goes through `brg-guard log`, which
    refuses a linked `.bearing` or state directory, never follows a link,
    never blocks on a FIFO, starts a fresh log over a hard link, and records
    printable ASCII only with the label capped at 120 bytes. It needs
    python3; without it nothing is logged.
  - Every git a hook starts runs with no filter driver (each one any config
    defines gets an empty clean, smudge and process), no external diff, no
    pager (`GIT_PAGER=cat`) and `log.showSignature=false`, beside the
    existing `core.fsmonitor=false` and `core.hooksPath=/dev/null`.
  - No hook runs a git command that reads file contents (`git status`,
    `diff`, `add`), so a filter driver that appears after the hooks list
    them (a loop toggling it in an included file) never runs:
    `brg-changed` counts changes from the index's stat data, HEAD's tree
    and the untracked list (`git ls-files`, `git ls-tree`) by mtime and
    size. The session line, the Stop gate and reminder, the precompact
    snapshot and brg-session's checkpoint all use it; `brg-changed --short`
    prints git's short status codes.
  - `brg-update-check` (SessionStart) runs `git ls-remote` from `/` under
    `env -i` with no system config and an empty global config, and reads
    its output from a pipe, never a file under TMPDIR.
  - The SessionEnd hook writes `docs/progress/<ID>.md` through
    `progress.py write`, which opens `docs` and `docs/progress` without
    following a link, reads the file only as a regular file with one link
    (a link, a FIFO or a hard link is refused) and replaces it by rename;
    its mark goes through `brg-guard state-write`. Its rehearsal is
    `progress.py write --dry-run`, so it copies no file anywhere.
    `progress.py show` prints a progress file read the same way.
- The repository template's pre-push hook refuses every agent push: a
  branch, a tag (even when no branch is pushed) and a deletion. The opt-in
  push never passes through it, since it pushes from a fresh clone that
  runs no repository hook.
- `brg-config` refuses to set `BEARING_AUTO_PUSH` in either spelling, and
  an exported `BEARING_AUTO_PUSH` is never read.
- The settings template denies `Edit(~/.config/bearing/**)`,
  `Edit(~/.gitconfig)`, `Edit(~/.config/git/**)` and
  `Bash(bash *bin/brg-push run*)`, and the sandbox denies writes to those
  directories; a brg-guard row refuses `brg-push run` from Bash, and that
  row is the control. It also denies Edit and Write on `./.git/**`,
  `**/.git/**`, `~/.local/bin/**`, `~/go/bin/**` and `~/.config/git/**`:
  the sandbox covers Bash only, autopilot's child has Edit and Write, and
  the hooks read `.git/config` and take a formatter from those two bin
  directories. A deny outranks any allow, `--allowedTools` included.
- `progress.py set` reads `git status -z`, so a name with a space counts,
  and counts every `.bearing/` file outside `.bearing/state/`.
- AGENTS.md rule 2 names the one exception to "never push": the opt-in
  task branch push. merge-request and autopilot descriptions say "pushes
  only where opted in"; merge-request requests the push after the check;
  autopilot runs `make check` again after its report commit, then requests
  the push, and its `mr` gate accepts a push recorded by `brg-push`. Every
  other "never pushes" claim in the docs and the developer guide names
  the exception.
- The workflow skill reads the recorded flow (`brg-config get flow`)
  before it picks one, on the question path as well as the menu.
- The precompact snapshot and brg-session's checkpoint and timeline go
  through `brg-guard state-write`, which refuses a linked `.bearing` or
  state directory, never writes through a link or a hard link, never
  blocks on a FIFO and replaces the file by rename; the timeline still
  rotates at 512 KB. brg-session reads its timeline only as a regular
  file.

### Security
- The opt-in push runs outside the sandbox, so it runs nothing the
  repository defines: the clone is made under
  `<passwd home>/.config/bearing/tmp` (mode 700, hidden from the
  sandbox) with no checkout, no repository hooks and no system config,
  under a cleared environment and a generated global config holding only
  the engineer's `credential.*` keys; the clone's own config is re-read
  and refused if it holds a key git clone does not write. A source with
  alternates, a promisor remote, a partial clone or an `includeIf`
  section is refused, and so is a git older than the patched releases
  (2.45.1, or 2.39.4, 2.40.2, 2.41.1, 2.42.2, 2.43.4, 2.44.1 on those
  lines). The push runs `--no-follow-tags`, never forced, to the URL the
  engineer listed, and the branch and commit are checked again in the
  clone before it. Every write `brg-push` makes in `.bearing/state` never
  follows a link.
- The SessionEnd hook no longer writes through a link: an agent could link
  the mark's temporary name or `docs/progress/<ID>.md` to a file in the
  home directory (a shell startup file) and have the hook write its next
  step there, and the hook copied a linked progress file into TMPDIR. See
  Changed.
- `brg-update-check` no longer reads the repository's git config: a
  `credential.helper`, `core.askPass` or `core.sshCommand` (through a url
  rewrite) there ran outside the sandbox at session start.
- The edit hook's prettier check parses the config: an escaped
  `"\u0070lugins"` key passed the old text match and loaded a repository
  plugin.
- The hooks no longer take programs from the environment they start with.
  The first lines of `hooks/scripts/lib.sh` and `brg-guard` set `PATH` to
  `/usr/bin:/bin:/usr/local/bin:/opt/homebrew/bin` and unset `BASH_ENV`,
  `ENV`, `CDPATH` and every `PYTHON*`, `LD_*` and `DYLD_*` variable, the
  hook entry scripts run no program before that, and every `python3` a
  hook runs uses `-I`. So no bash a hook starts sources a `BASH_ENV`
  script, and no `jq`, `git`, `python3` or `bash` comes from a directory
  put first on `PATH`. What remains: a `BASH_ENV` or `PATH` in the
  harness's own environment acts before the first line of a hook script
  runs (bash sources `BASH_ENV` at startup, and the harness finds `bash`
  on its `PATH`), which is outside Bearing's reach. The agent's route to
  it was a settings file's `env`; the settings template now denies Edit
  and Write on `./.claude/settings.json`, `./.claude/settings.local.json`,
  `~/.claude/settings.json` and `~/.claude/settings.local.json`, and the
  sandbox denies Bash writes to the two project files.
- The edit hook's prettier check walks the path prettier walks (the edited
  file's directory up to the repository root, no link resolved) and skips
  prettier with a note when any directory on it is a link or resolves
  outside the root: a linked directory let prettier find a JS config the
  check never saw.
- SessionStart creates `.bearing/state`, prunes old session marks and
  writes the new one without following a link: a linked `.bearing` or
  `.bearing/state` is refused, so no directory or file is made, and none
  removed, in its target. `brg-push` no longer makes `state` inside a
  linked `.bearing` before refusing it.

### Notes for existing repositories
- Upgrading from 0.8.0 or earlier: the GenAI and ML skills moved to
  `bearing-genai`. Run `claude plugin install bearing-genai@bearing` (or
  rerun `install.sh`, or let `upgrade-tools` offer it), and change any
  reference written `bearing:<genai skill>` to `bearing-genai:<skill>`.
- Copy the six Edit and Write denies on `//opt/homebrew/bin/**`,
  `//usr/local/bin/**` and `//home/linuxbrew/.linuxbrew/bin/**` from the
  settings template into `.claude/settings.json`, then run `brg-doctor`.
- The edit hook no longer runs `make check-file` or any linter after each
  edit; that per-file feedback moves to the session. Run
  `make check-file FILE=<path>` after an edit (the repository template's
  CLAUDE.md now says so; an onboarded repository's own CLAUDE.md keeps the
  old line until you change it). The Stop gate still holds the session to
  `make check`.
- A formatter installed only outside the fixed directories (under nvm, in
  a project's `node_modules` or virtualenv) is now reported as not
  installed by the edit hook; `make format` or `make fix` formats in the
  session.
- A hook's change count now comes from timestamps and sizes, not content:
  a file whose timestamp changed but whose content did not counts as
  changed, until the next `git status` or commit refreshes the index.
- Prettier runs from the edit hook only under `.prettierrc.json` or a
  `package.json` `prettier` object of plain formatting options; a
  repository with `.prettierrc`, a YAML, TOML, JSON5 or JS config formats
  in the session (`make format`), or moves its options to
  `.prettierrc.json`.
- Before opting in to the push, copy the template's new settings into each
  onboarded repository's `.claude/settings.json`: the denies
  `Edit(~/.config/bearing/**)`, `Edit(~/.gitconfig)`,
  `Edit(~/.config/git/**)`, `Write(~/.config/git/**)`, Edit and Write on
  `./.git/**`, `**/.git/**`, `~/.local/bin/**` and `~/go/bin/**`, and
  `Bash(bash *bin/brg-push run*)`, and `~/.config/git` in the sandbox's
  `filesystem.denyWrite`. Without them the agent's Edit tool can write
  `BEARING_AUTO_PUSH` into bearing.env and opt the repository in from the
  next session.
- Copy the template's settings denies into each onboarded repository's
  `.claude/settings.json` too: `Edit` and `Write` on
  `./.claude/settings.json`, `./.claude/settings.local.json`,
  `~/.claude/settings.json` and `~/.claude/settings.local.json`, and the
  two project files in the sandbox's `filesystem.denyWrite`. Without them
  the agent can set `BASH_ENV` or `PATH` in a settings `env`, and every
  hook after that starts with it, outside the sandbox. Afterwards change
  those settings files by hand; Claude is denied them. `onboard-repo`
  proposes the new template as `.claude/settings.json.bearing-new`.
- Add a `## Task paths` table to every `docs/design/flows/*/flows.md`
  (columns Task, Story, Kind, Entry, Path, Screens, Interactions, Over; the
  `ux-flows` skill's `references/task-paths.md` has the format), then run
  `flows_check.py`. Without it the flows check fails.
- A `data-needs.md` written by hand uses ids F-nn for fields and A-nn for
  actions; `states_check.py --needs` rejects other shapes. Renumber any id
  that repeats another feature's, and add the read action to each screen
  that shows server data.
- An autopilot run saved before the `test_run` stage, with
  `test_automation` and a later stage done, has `test_run` carried as done
  when it is loaded, with a note; dod's full run still checks every suite.
  A run that stopped right after `test_automation` runs the new gate next.
- A run past `review` before this change keeps it; a run that reaches the
  review gate now needs branch-review to have written `verdict.txt`, so an
  older review folder is reviewed again.
- definition-of-done item 14 is new: the first dod on a branch runs every
  suite beyond unit, and a unit-only repository records `"n_a": "no suite
  beyond unit"`. Record each suite left to CI as a `test_run.<suite>`
  decision (unattended) or a `CI-accepted:` state line (attended).
- Commit the full run's report under `docs/testing/reports/` before the
  merge request; the dod gate accepts a full run followed only by that
  report.
- Evidence written by test-run before `selection` existed has no
  `selection` key and fails the test_run and dod gates; run test-run again.
- Opt-in push (off by default; nothing changes until you opt in): add
  `BEARING_AUTO_PUSH="<push URL> [<push URL> ...]"` (full ssh, scp-style
  or https URLs, space-separated, no `export`) to `~/.config/bearing/bearing.env` under your
  passwd home, never to a repository or the environment. The Stop hook
  then pushes the task branch from a clean clone after the gate. It needs
  git at or above the patched releases (2.45.1, or 2.39.4, 2.40.2,
  2.41.1, 2.42.2, 2.43.4, 2.44.1 on those lines). A repository whose
  config has an `includeIf` section, or a partial clone, cannot auto push
  (`brg-push check` names the reason). The repository's pre-push hook,
  once updated from the template, refuses every agent push, so an agent
  can no longer push through it by any other route.
- Site repositories: run `start-task --flow site` on the first task to
  record the site flow; later tasks and `brg-session` follow it.
- Task sets: start each member with the same id, name, type and
  `start-task --repos <list>` line the first run prints, one session per
  repository.

### Noted
- impeccable `critique` asks a question at its close, so an unattended run
  (`BEARING_NONINTERACTIVE`, `BEARING_AUTOPILOT`, `--unattended`) runs only
  `audit`; design-directions skips the impeccable round when unattended and
  takes its own fallback.
- Plugin size: `bearing` is at 456 files; the cap is under 512.

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
