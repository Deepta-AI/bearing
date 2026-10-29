# Contributing to Bearing

Bearing lives at <https://github.com/Deepta-AI/bearing> under the MIT
licence. Issues and pull requests are welcome there; a vulnerability goes
privately, as [SECURITY.md](SECURITY.md) describes.

## A pull request, start to finish

1. Fork `Deepta-AI/bearing` on GitHub and clone your fork:
   ```bash
   git clone git@github.com:<you>/bearing.git && cd bearing
   git remote add upstream https://github.com/Deepta-AI/bearing
   make hooks
   ```
   `make hooks` installs `.githooks/pre-push`. Push with `make push`: it
   runs `make gate` on the commit (`make check`, then, with Docker
   running, `make ci-bash32`, the bash 3.2 CI job in the same image),
   then pushes the branch; `FORCE=1` adds `--force-with-lease`. The gate
   records each commit it passed on (`bin/gate-mark`, shared by every
   worktree), and the hook only checks that every commit being pushed
   passed: it refuses at once otherwise and never runs the gate itself,
   because a 15-minute gate inside the hook outlived the connection git
   had opened to the remote. The macOS and scaffold jobs run only in CI; `make lint-portable`
   (part of `make check`) rejects the BSD and missing-tool commands it
   knows (`sed -i`, `perl`, `grep -P`, `readlink -f`, `date -d`).
2. Branch from `main` with a short descriptive name, for example
   `feat/RustStack` or `fix/GuardSudoParse`.
3. Make the change, then run the gate:
   ```bash
   make check
   ```
   The last line is `check: passed`. Its first target, `validate`, runs
   `claude plugin validate --strict` and needs the Claude Code CLI;
   without it, run the other targets `make check` lists (the CI workflow
   does the same) and say so in the pull request.
4. If you touched a skill, the stage map or anything the sites render,
   run `make docs` and commit what it regenerates. `make lint-docs` (part
   of `make check`) fails on a stale generated file.
5. Commit in Conventional Commits form (`feat(guard): ...`,
   `docs: ...`), push the branch to your fork, and open a pull request
   against `main` of `Deepta-AI/bearing`. Say what changed, how you
   verified it (commands and their count lines), and what you did not do.
6. The `ci` workflow (`.github/workflows/ci.yml`) runs on the pull
   request: the checks, a scaffold of each of the eight stacks whose
   toolchains run on a Linux runner followed by that stack's own `make
   setup && make check` (the test suite scaffolds all thirteen), the guard
   and unit tests under bash 3.2, and the tests on macOS. Every job must
   be green before a maintainer merges.

## Forking without diverging

A team that keeps its own fork, for company skills or a pinned version:

1. Set `BEARING_KIT_REMOTE` in `~/.config/bearing/bearing.env` to the
   fork's git URL. `install.sh`, `brg-scaffold` and `brg-adopt` read it,
   so every developer installs from the fork and every repository's
   settings point at it. Developers clone the fork instead of the public
   repository, or pass `install.sh --remote <fork git url>`.
2. Fill in `NOTICE.md` for your distribution.
3. Keep company-specific skills in a separate plugin, or give their names
   a prefix of your own, so upstream merges stay clean. A fork that adds
   unprefixed skills under `plugins/*/skills/` must accept merge conflicts when
   upstream adds a skill of the same name.
4. Pull upstream with `git pull upstream main`, run `make check`, and
   bump `VERSION` with a CHANGELOG entry before rolling out.
5. The fork runs the same CI on GitHub (`.github/workflows/`) or on
   GitLab (`.gitlab-ci.yml`, the twin of both workflows).

## Where things live

The repository is a marketplace of four plugins, and only what a plugin
needs at run time sits inside one:

- `plugins/bearing/`: the workflow skills, `agents/`, `hooks/`, `bin/`
  (the `brg-` scripts, with `brg-kit-paths`, which finds the other
  plugins) and `templates/`. Required.
- `plugins/bearing-backend/skills/`: go, python, node, data-pipeline, infra.
- `plugins/bearing-apps/skills/`: react, nextjs, react-native, flutter,
  ios, android.
- `plugins/bearing-genai/skills/`: the GenAI and ML skills (genai-design, rag,
  llm-agent, llm-eval, llm-gateway, speech, and the rest).
- Outside every plugin: `evals/`, `tests/`, `site/`, `devguide/`, `docs/`
  and `bin/` at the root (generators, lints, the eval harnesses, and
  `bin/kit_paths.py`, which asks `brg-kit-paths` where the skills are).

A script that looks for a stack's templates or checklist goes through
`plugins/bearing/bin/brg-kit-paths` (`--skill <name>`, or the skill roots
with no argument), never `skills/<stack>` under its own plugin root: in
an install each plugin sits in its own cache folder, and a missing stack
plugin must be named, not tripped over. A skill that mentions a skill of
another plugin uses that plugin's prefix (`bearing:tech-decision` from a
stack skill, `bearing-backend:go` from a workflow skill); `make
lint-skills` resolves all four prefixes. `make lint-plugin-size` keeps
each plugin under 512 files and every non-image file under 256 KiB, the
plugin directory's limits.

## Adding or changing a skill

- `/bearing:new-skill <name>` scaffolds the directory with the required
  sections, runs the lints and hands the skill to skill-creator for
  evals. The lint (`make lint-skills`) enforces: a directory name of
  lowercase words joined by hyphens, at most 64 characters, `name` equal
  to the directory, a description of at most 150 characters that says
  "Use when" with at least two quoted phrases, the sections Inputs, Steps,
  Output contract and Gotchas (stack skills use their own set), every
  backticked `templates/` or `references/` path existing, every
  `bearing:<name>`, `bearing-backend:<name>`, `bearing-apps:<name>` or `bearing-genai:<name>` it
  mentions resolving to a skill (or, for bearing, an agent), and `Skill`
  in `allowed-tools` for any skill that runs the decision protocol.
- Lead the description with the job and the phrases a user says. Claude
  Code lists skills within a budget (1% of the context window); past it,
  skills are shown by name only (see
  [Keep the skill listing lean](docs/INSTALL.md#keep-the-skill-listing-lean)).
  `make lint-listing` keeps Bearing's whole listing under 19,000
  characters: on 28 Oct 2026 it was 25,800, and the 16 skills loaded last
  (the app and GenAI ones) were shown by name only and loaded on 12 of 33
  requests.
- Do not set `disable-model-invocation: true` on a skill Claude should
  load from plain requests: it hides the skill from Claude entirely.
- `make lint-tools` checks that every command a skill's Inputs, Steps or
  Commands section tells the agent to run is granted by its
  `allowed-tools`. A command the skill only prints for the engineer (an
  install line, a target it adds) goes in `bin/lint-skill-tools.allow`
  with its reason; commands the guard blocks (push, tag, publish) are
  exempt on their own.
- A skill works on its own: every input names a fallback. Never make a
  skill depend on another skill having run.
- A skill never pushes, merges, tags, deploys or opens an MR, except the
  opt-in push: merge-request and autopilot may run `brg-push request`
  where the engineer listed the repository in `BEARING_AUTO_PUSH`, and the
  Stop hook then pushes the task branch from a fresh clone after the gate.
  Otherwise the skill prints the command for the engineer.
- Place the skill in the stage map in `bin/gen-guide.py`: a `CATEGORY`
  entry and, where the workflow runs it for a stage, a `STAGES` row.
- Give it a reader's summary in `docs/skill-summaries.json`: `what` (one
  sentence on what it does and leaves behind) and `when` (completes "Use
  it when ..."). The sites show these; the frontmatter description stays
  written for triggering.
  `make docs` regenerates `docs/WORKFLOW.md`, `docs/SKILLS.md` and the
  handbook data, and fails naming whatever is missing.
- Where a stage calls an installed skill from another pack instead of a
  Bearing skill, its name must appear in `docs/known-skills.txt`.
- Nothing published (the docs, the sites, the skills) compares Bearing
  with another pack or ranks other people's skills; `gen-guide.py` fails
  a flow step that does.

## How evals work

Every skill carries evals in `evals/<name>/evals.json`, outside the skill
folder so a run that follows the skill never reads its grading. The cases
use skill-creator's schema: a prompt, an optional fixture repository under
`evals/<name>/files/`, and `expectations` a grader can check (a file
written, a count printed, a refusal on empty input).

- `make lint-evals` requires the file for every skill not on
  `evals/.pending` (the skills that predate the rule; the list only
  shrinks, and a pending skill that gains evals must leave it).
- Write and run the cases with Anthropic's skill-creator: it runs each
  case with the skill and without it, grades and benchmarks, and it tunes
  the description with near-miss prompts. `new-skill` step 7 hands a new
  skill to it. A skill that does not pass more of its cases than
  the no-skill baseline is not added.
- `bin/skill-evals.py` runs the same cases with the skill and with no
  skill, blinds the arms for the grader, and records the result in
  `.scratch/private/comparisons.json`, an untracked file for the
  maintainers. `python3 bin/skill-evals.py --help` lists its commands.
- `bin/skill-evals-run.py` drives those commands with no one at the
  keyboard: executor and grader sessions through `claude -p` in Claude
  Code's Bash sandbox (network limited to localhost, no Skill tool, no
  settings), a rotating set chosen from `evals/scoreboard.jsonl` (changed
  since last measured, then never measured, then oldest; `--max`, default
  5), and a `summary.json` the scoreboard copies in. `--list` shows the
  set without running it. Three skills are measured at once
  (`--parallel-skills`), and `-j` (default 6) caps the claude sessions
  open at once across them, so the load on the subscription stays bounded.
- Workspaces go under `.scratch/skill-evals/`, which git ignores.
- `make harness-eval` drives real Claude Code sessions against the hooks
  (push, deploy, edit lint, stop gate, compaction). It needs the claude
  CLI and is not part of `make check`.
- `make trigger-eval` checks that a plain request loads the right skill.
  Each skill has three requests that should load it and two near misses
  that should not, in `evals/triggers.json`. Each request runs in a fresh
  headless session with only the four plugins loaded;
  `SOURCES=user,project,local` runs with everything installed on your
  machine instead. `make lint-triggers` (part of `make check`) holds the
  file to every skill and refuses a request that copies a phrase quoted
  in the skill's own description. When you add a skill, add its requests;
  when you change a description, run `make trigger-eval ONLY=<name>`.
- `make evals-weekly` runs harness-eval, skill-evals-run (five skills)
  and trigger-eval on a clean tree, in that order, and appends one row to `evals/scoreboard.jsonl`: the commit measured,
  recall and false triggers overall and per skill, and the harness pass
  rate per scenario, and each measured skill's pass rate with and without
  it. It fails on zero cases, and on recall down or false triggers up by
  more than 5 points, any harness scenario falling, or a skill's
  with_skill rate down more than 10 points since it was last measured;
  the row is kept either way. Trigger-eval takes a rotation
  (`bin/trigger-rotation.py`): every skill changed since its last
  measured row plus a quarter of the rest by ISO week, about 140 cases,
  because all 547 at once used up the plan's session limit. A session
  refused for the usage limit stops every runner: what did not run is
  recorded as not run, never as failed, and the run exits 3. Each run's
  output stays in `.scratch/evals-weekly/`. The file is tracked so
  a merge request can show its effect on the score; neither site reads
  it. `make evals-timer` prints the systemd user units that run it every
  Sunday from a clone kept on main; commit the new row after each run.
- `make skill-tune` (SKILL=<name>, else the weakest measured skill) is
  the improvement loop: a sandboxed session edits a copy of the skill
  from the expectations it last failed, the copy must pass the skill
  lints, then both are measured side by side. The edit is kept only when
  with_skill rises by 10 points and the margin over no skill does not
  shrink, as `candidate.patch` and `report.md` under
  `.scratch/skill-tune/`; read it, then `git apply` it on a branch.
- `make claude-drift` compares the installed Claude Code (flags, and the
  hook events and settings keys in its settings schema) with
  `docs/claude-code-surface.json`: what is new, which hook events Bearing
  does not use, and anything Bearing uses that is gone (that fails). After
  reading the new items, `make claude-drift RECORD=1` moves the baseline.
- `make pin-refresh` lists every pin in `pinned-packs.txt` that upstream
  has moved past, with the files changed under the pinned path. It edits
  nothing: read the diff it names before moving a pin. It also names any
  link under the pinned path: the installer would copy it as a link.
- `make eval-audit` (SKILL=<name>) reads every graded run on the machine
  and sorts each expectation: discriminating, no signal (passes in every
  run of every arm), never passes, favours no skill, and flagged by a
  grader's eval_feedback. Rewrite or drop the no-signal, never-passes and
  flagged ones; an expectation that measures nothing makes a skill look
  as good as no skill.
- Mark one case per skill `"held_out": true` once a skill has three or
  more: skill-tune measures it but never shows its failures to the
  proposer, and rejects an edit whose held-out cases fall. A held-out case
  tests behaviour the other cases do not (adr's case 3 is the proposed
  path; the other two are accepted decisions).
- `python3 bin/skill-evals.py alternative <skill> <invoke>` pairs a
  Bearing skill with an installed rival so the next measurement runs a
  third arm. The pairing lives in the untracked results file; a rival is
  adopted only on its scores.

## Testing a change

- `make check` is the gate: plugin validation (strict), skill lint, tool
  grants, evals, JSON, shellcheck, prose, neutrality, version match, the
  per-session load budget, document templates, docs freshness and
  `tests/run.sh`. Each prints a count and fails on empty input.
- `make test` alone runs the suite: the guard deny table, hook fixtures
  through every harness adapter, scaffold of every stack, adopt
  idempotency, tracker adapters against fake servers, deterministic docs.
- `make site` and `make devguide` build the two sites (node 22 and pnpm).
- Try the plugin from your working copy: `claude plugin marketplace add
  "$PWD"`, then `claude plugin install bearing@bearing`, restart Claude
  Code and try the skill in a scaffolded repository. The plugin cache is
  keyed by version: after an edit, bump `VERSION` or run `claude plugin
  uninstall bearing@bearing` and install again.

## Releasing

Maintainers only.

1. Collapse `[Unreleased]` in `CHANGELOG.md` into the new version.
2. Update `VERSION`; `make lint-version` checks `plugin.json` and
   `marketplace.json` match.
3. `make docs` and commit the regenerated files.
4. A person tags and pushes: `git tag -a vX.Y.Z -m "bearing X.Y.Z" && git
   push origin main --tags`. The `docs` workflow deploys the handbook
   and the developer guide on the push to main.
5. Developers upgrade with `/bearing:upgrade-tools`, or `claude plugin
   update bearing@bearing` on a plugin-only install.

## Style

- No em dashes in prose, commits, docs or comments. Rewrite the sentence.
- No AI attribution lines in commits or pull requests.
- Conventional Commits with the task id when there is one.
- Scripts run on macOS bash 3.2 and Linux; shellcheck clean.
