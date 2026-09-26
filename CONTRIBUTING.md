# Contributing to Bearing

Bearing lives at <https://github.com/Deepta-AI/bearing> under the MIT
licence. Issues and pull requests are welcome there; a vulnerability goes
privately, as [SECURITY.md](SECURITY.md) describes.

## A pull request, start to finish

1. Fork `Deepta-AI/bearing` on GitHub and clone your fork:
   ```bash
   git clone git@github.com:<you>/bearing.git && cd bearing
   git remote add upstream https://github.com/Deepta-AI/bearing
   ```
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

The repository is a marketplace of three plugins, and only what a plugin
needs at run time sits inside one:

- `plugins/bearing/`: the workflow skills, `agents/`, `hooks/`, `bin/`
  (the `brg-` scripts, with `brg-kit-paths`, which finds the other two
  plugins) and `templates/`. Required.
- `plugins/bearing-backend/skills/`: go, python, node, data-pipeline, infra.
- `plugins/bearing-apps/skills/`: react, nextjs, react-native, flutter,
  ios, android.
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
lint-skills` resolves all three prefixes. `make lint-plugin-size` keeps
each plugin under 512 files and every non-image file under 256 KiB, the
plugin directory's limits.

## Adding or changing a skill

- `/bearing:new-skill <name>` scaffolds the directory with the required
  sections, runs the lints and hands the skill to skill-creator for
  evals. The lint (`make lint-skills`) enforces: a directory name of
  lowercase words joined by hyphens, at most 64 characters, `name` equal
  to the directory, a description of at most 220 characters that says
  "Use when" with at least two quoted phrases, the sections Inputs, Steps,
  Output contract and Gotchas (stack skills use their own set), every
  backticked `templates/` or `references/` path existing, every
  `bearing:<name>`, `bearing-backend:<name>` or `bearing-apps:<name>` it
  mentions resolving to a skill (or, for bearing, an agent), and `Skill`
  in `allowed-tools` for any skill that runs the decision protocol.
- Lead the description with the job and the phrases a user says. Claude
  Code may shorten the skill listing on a busy machine (see
  [Keep the skill listing lean](docs/INSTALL.md#keep-the-skill-listing-lean)),
  and the start of the description is what survives.
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
- A skill never pushes, merges, tags, deploys or opens an MR. It prints
  the command for the engineer.
- Place the skill in the stage map in `bin/gen-guide.py`: a `CATEGORY`
  entry and, where the workflow runs it for a stage, a `STAGES` row.
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
  maintainers; nothing published reads it.
  `python3 bin/skill-evals.py --help` lists its commands.
- Workspaces go under `.scratch/skill-evals/`, which git ignores.
- `make harness-eval` drives real Claude Code sessions against the hooks
  (push, deploy, edit lint, stop gate, compaction). It needs the claude
  CLI and is not part of `make check`.

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
