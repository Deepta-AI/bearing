# Bearing

Bearing is a development workflow for teams that build software with
coding agents. Every stage of a product, from the brief to the runbook,
has one skill that runs the checklist, and the rules that must not bend
(the agent never pushes, every gate prints a count, everything traces)
are enforced by hooks and git rather than by prose. It is for engineers on
any harness (Claude Code as a plugin; Cursor, Codex, Gemini CLI, Copilot
and others through `harness-setup`), for tech leads who want one standard
across repositories, for PMs and designers who want the PRD, the backlog
and the screens to come out in a known shape, and for solo developers who
want the discipline without a team to supply it. Nothing in the kit names
a company, a git host or a tracker: those are yours to configure.

Bearing is open source under the MIT licence. Its home is
<https://github.com/Deepta-AI/bearing>. Two sites are built from this
repository: the [handbook](https://bearing-handbook.vercel.app) (how to use
Bearing: every stage, skill and flow) and the
[developer guide](https://bearing-devguide.vercel.app) (how Bearing works
inside).

## Install

Bearing is one marketplace with three plugins:

| Plugin | What it holds | Needed |
| --- | --- | --- |
| `bearing` | the workflow skills, the seven subagents, the hooks and the guard behind them, the scripts (`bin/`) and the repository templates | required |
| `bearing-backend` | the stack skills and scaffold templates for Go, Python, Node, data pipelines (dbt, Airflow) and infrastructure (Terraform, Kubernetes) | optional |
| `bearing-apps` | the stack skills and scaffold templates for React, Next.js, React Native, Flutter, iOS and Android | optional |

**The plugins only.** Inside Claude Code:

```
/plugin marketplace add Deepta-AI/bearing
/plugin install bearing@bearing
/plugin install bearing-backend@bearing   # optional
/plugin install bearing-apps@bearing      # optional
```

Install the stack plugins your repositories use. Without one, its stack
skills are absent, and scaffolding, adopting or reviewing that stack stops
with the line that installs it (`/plugin install bearing-backend@bearing`)
instead of failing on a missing path. The plugins write no configuration
file, install no companion packs and leave no checkout on disk, so the
tracker stays `none` until you create `~/.config/bearing/bearing.env`
yourself (copy
[plugins/bearing/templates/user/bearing.env](plugins/bearing/templates/user/bearing.env)).

**The full install.** A checkout at `~/bearing` and the installer:

```bash
git clone https://github.com/Deepta-AI/bearing ~/bearing
bash ~/bearing/install.sh
```

It registers the checkout as the marketplace and installs all three
plugins, then writes `~/.config/bearing/bearing.env` (mode 600, never
overwritten), a personal `~/.claude/CLAUDE.md` starter if you have none,
the companion packs for the profile (Superpowers, gstack and GSD Core by
default; `--profile full` adds the open-source packs the workflow names),
then runs the doctor. The commands in these docs that start with
`~/bearing/plugins/bearing/bin/` run from that checkout, and
`install.sh --no-claude` sets up other harnesses from it. Every flag is in
[docs/INSTALL.md](docs/INSTALL.md). A fork sets `BEARING_KIT_REMOTE` so
developers and repositories install from it (see
[CONTRIBUTING.md](CONTRIBUTING.md)).

## What Bearing runs on your machine

Everything below is in this repository; nothing else runs.

**Hooks** (`plugins/bearing/hooks/hooks.json`, in the bearing plugin; the
stack plugins have none). Each script is a thin adapter that reads the
event JSON with `jq` and calls one subcommand of
`plugins/bearing/bin/brg-guard`:

| Event (matcher) | Script | What it does | Blocks? |
| --- | --- | --- | --- |
| `SessionStart` (startup, resume, compact) | `session-start.sh` | `brg-guard session`: prints the branch, the task id, the count of changed files, the handoff state from `.bearing/state/`, the review checklists for the repository's stacks and, after a compaction, the snapshot `PreCompact` wrote | no |
| `UserPromptSubmit` | `inject-task-id.sh` | `brg-guard task-id`: prints `Task: <ID>` when the branch carries a ticket id the prompt lacks | no |
| `PreToolUse` (Bash) | `block-publish.sh` | `brg-guard command`: refuses the commands listed below, and any command it cannot read (fail closed, which is every command when `jq` is missing) | yes, exit 2 |
| `PostToolUse` (Edit, Write, MultiEdit) | `format-file.sh` | `brg-guard format`: formats the edited file with the repository's own formatter when one is installed (gofmt, prettier, ruff or `uv run ruff`, ktlint, swiftformat and the like); then `brg-guard check-file`: `make check-file FILE=<file>` when the repository's Makefile has that target, else `bash -n` and shellcheck, a JSON parse or `py_compile` | sends Claude back with the problems; the edit stands |
| `PreCompact` | `precompact.sh` | `brg-guard precompact`: writes `.bearing/state/<branch>.compact.md` (branch, changes, check state, the last requests) | no |
| `Stop` | `stop-summary.sh` | `brg-guard stop-gate`: when files changed in this session since `make check` last passed, sends Claude back once with the reason; the second stop only reminds, so it cannot loop | once |

The hooks write only under the repository's `.bearing/state/` (the
handoff and compaction snapshots, and `gates.log` with what each gate
decided). They make no network call of their own; the one indirect case
is the format hook in a Python repository without `ruff` on PATH, where
`uv run ruff` lets uv install the project's own locked dependencies.

**What `brg-guard` blocks.** `bash plugins/bearing/bin/brg-guard --verbs`
prints the table: 135 rules over 54 programs, matched after wrappers such
as `env`, `sudo` and `bash -c` and any path are stripped.

- git that publishes or rewrites history: `push`, `commit --amend`,
  `rebase`, `reset --hard`, `filter-repo`, `filter-branch`, `clean -fdx`,
  `remote set-url` or `remove`, `branch -D`, `stash drop` or `clear`,
  `worktree remove`, `reflog expire`, `gc --prune`, `update-ref -d`, `tag -d`.
- Forge writes: `glab` and `gh` merge or pull request create, merge and
  approve, release create and delete, repository delete.
- Package publishing: npm, pnpm and yarn `publish`, cargo `publish`,
  twine `upload`, uv `publish`, poetry `publish`, gem `push`, mvn `deploy`,
  gradle `publish`, dotnet `nuget push`, goreleaser `release`.
- Image pushes: docker `push` (and `build --push`, `compose push`),
  podman `push`.
- Infrastructure and deploys: terraform, tofu and terragrunt `apply`,
  `destroy` and state changes, pulumi `up` and `destroy`, kubectl `apply`,
  `delete`, `rollout`, `scale`, `patch`, `replace`, `drain`, `cordon`, helm
  install, upgrade, rollback and uninstall, the AWS, gcloud and az deploy
  and delete verbs, cdk, sam, serverless, ansible-playbook, vercel,
  netlify, fly, railway, firebase, eas build, submit and update,
  fastlane, capistrano.
- Destructive or remote system commands: `rm -rf` on anything outside the
  repository (or a path held in a variable), `dd`, `mkfs`, `chmod -R 777`,
  `chown -R /`, `shutdown`, `reboot`, `killall`, `pkill -f`, `ssh`, and
  `scp` or `rsync` to a remote.

The engineer runs these; the agent prints the command instead.

**External fetches.** The plugins download nothing when they install or
load. The steps below do, and every version or commit they fetch is set
in one file, [plugins/bearing/bin/pinned-packs.txt](plugins/bearing/bin/pinned-packs.txt):
`install.sh`, `brg-install-packs`, `brg-harness` and `brg-doctor` read
their pins from it, and `tests/unit/pins_match.sh` fails when a skill
names a version the file does not hold or an `npx`, `uvx` or `uv --with`
fetch without one.

| What | When | Fetches | Pinned |
| --- | --- | --- | --- |
| `install.sh` | you run it | the marketplace from GitHub (or your checkout) and the three plugins | the commit you install from |
| `install.sh`, profile standard or full | you run it | gstack: `git fetch --depth 1 https://github.com/garrytan/gstack.git 2a113ae7e623f590095bcaaa0cc581c9a10a6632` into `~/.claude/skills/gstack`, then its own `./setup`, which installs gstack's dependencies from its `bun.lock` and Playwright's Chromium; an existing gstack checkout is left as it is | commit `2a113ae7e623` (`--skip-gstack`) |
| | | GSD Core: `npx --yes @opengsd/gsd-core@1.14.0 --global --claude` | `1.14.0` (`--skip-gsd`) |
| | | Superpowers: `claude plugin install superpowers@claude-plugins-official` | not pinnable: the official marketplace takes no version, so Claude Code installs its current release (`--skip-superpowers`) |
| `plugins/bearing/bin/brg-install-packs`, profile full | `install.sh --profile full`, or you run it | the `skill` and `plugin` rows: each repository fetched at its commit, skill folders copied to `~/.claude/skills` | the full commit on each row |
| | | the `cli` rows: `npx --yes skills@1.7.0 add <repo>#<commit> --skill <name>` for ui-craft, pm-skills, addyosmani, dash0, qa-skills, Vercel agent-skills, conventional-changelog and trailofbits `differential-review` | the skills CLI at `1.7.0`, each repository at the full commit on its row (`--skip-skills-cli`) |
| | | the Playwright agent skill: `npx --yes @playwright/cli@0.1.21 install --skills -g` | `0.1.21` (`--skip-playwright`) |
| | | six official-marketplace plugins (frontend-design, code-review, claude-security, mattpocock-skills, mcp-server-dev, playwright) | not pinnable, as for Superpowers (`--skip-official`) |
| `plugins/bearing/bin/brg-harness` (`harness-setup`) | you set up another harness | the Bearing skills: `npx --yes skills@1.7.0 add <kit remote>#v<VERSION> --all` | the skills CLI at `1.7.0`, the kit at the release tag of the installed version (`--kit-ref` names another tag or commit; `--no-skills` skips it) |
| Skills that run a package | only when the skill reaches that step, within the skill's `allowed-tools` | `npx @redocly/cli@2.54.3 lint` and, through `make api-conformance`, `uvx schemathesis@4.28.0` and `uv run --with pyyaml==6.0.3` (openapi-spec); `npx @cyclonedx/cyclonedx-npm@6.0.1` (license-compliance); `npx @modelcontextprotocol/inspector@2.8.0` (mcp-server); `npx clinic@13.0.0` and `npx lighthouse@13.5.0` (performance); `npx tsx@4.23.15` (llm-eval); `uv run --with python-docx==1.2.0 --with openpyxl==3.1.5` (client-deliverables); `uv run --with pytest-repeat==0.9.4` (test-heal); `pnpm dlx shadcn@4.21.0 add` (bearing-apps:react and nextjs); `npx skills@1.7.0 list` and `update` (upgrade-tools) | the exact version shown on each |
| | | `npx expo doctor` and `npx expo export` (bearing-apps:react-native) | not pinned here on purpose: they run the repository's own `expo` from its lockfile, which must match the Expo SDK |
| | | `docker run postgres:16` (data-model, `scripts/apply_check.sh`, a throwaway container) | by tag, the Postgres major the schema targets; the second argument names another image or a digest |
| Upgrades you ask for | `upgrade-tools`, `/gstack-upgrade`, `/gsd-update` | gstack and GSD Core through their own upgraders, which move to their latest release; the skills-CLI packs through `npx skills@1.7.0 update`, which stays at the commit each pack was installed from | past the pins by design: an upgrade is the request to leave them; `pinned-packs.txt` is where a new pin goes |
| CI of this repository | the `docs` workflow, the `handbook:vercel` and `devguide:vercel` jobs | the Vercel CLI through `npx --yes "$VERCEL_CLI"` | `vercel@59.26.0` in `.github/workflows/docs.yml` and `.gitlab-ci.yml` |

## Quickstart

Each step ends with one line you can check.

1. Install as above. The installer's last line:
   `install.sh: N installed, M already present, K skipped, 0 failed`.
2. Configure `~/.config/bearing/bearing.env` (the installer wrote it with
   placeholders; `BEARING_TRACKER=none` is valid), then check it:
   ```bash
   ~/bearing/plugins/bearing/bin/brg-tracker config
   ```
   First line: `tracker: none (from file)` or your tracker's name.
3. Restart the harness, then in any repository run `/bearing:doctor`.
   Last line: `brg-doctor: N checks, 0 missing, M optional`.
4. Put a repository on the standard: `/bearing:new-repo go-api InvoiceService`
   for a new one, `/bearing:onboard-repo --stack react-web` for an existing one.
   Last line: `brg-scaffold: N files written to <dir> (...)` or
   `brg-adopt: N files in standard (...): added A, kept K, conflicts 0 (core.hooksPath set)`.
5. Start a task: `/bearing:start-task TASK-142 InvoiceTotals`.
   Last line: `Next: <skill or action>`. From there `/bearing:workflow`
   names each next step.

## How the skills are used

You do not have to remember skill names. Ask in your own words ("write
the PRD for this brief", "is this branch ready for review") and Claude
loads the matching skill. Every skill can also be called directly as
`/bearing:<name>`, for example `/bearing:test-run` or
`/bearing:merge-request`. Names say the job (`definition-of-done`, not
`dod`) because on a machine with hundreds of skills Claude Code may list
some by name only; see
[Keep the skill listing lean](docs/INSTALL.md#keep-the-skill-listing-lean).
The stack skills live in the other two plugins and carry their prefix:
`/bearing-backend:go`, `/bearing-apps:react`. The subagents are called
the same way, `bearing:reviewer`, `bearing:critic` and so on; the skills
start them for you. The scripts behind the skills keep a `brg-` prefix
(`plugins/bearing/bin/brg-guard`, `plugins/bearing/bin/brg-tracker`).

## What you get, by stage

- Discover and plan: `prd`, `backlog`, `estimate`,
  `spike`, `explain-codebase`, `tech-debt`, tickets through `tracker-sync`
  in Jira, GitLab, GitHub, any REST tracker or none.
- Choose and architect: `tech-decision` (options, recommendation, you
  decide), `adr`, diagrams, HLD, LLD, API spec and lifecycle, auth,
  jobs, webhooks, patterns, data model, deployment, threat model.
- Design: UX flows, three variants to choose from, tokens, screens,
  themes, motion, a design review.
- GenAI: solution design, prompts, RAG, agents, MCP, guardrails, an LLM
  gateway, evals, training.
- Repository: scaffold or adopt for thirteen stacks (React, Next.js,
  Node, Go service and CLI, Python service and CLI, data pipelines, React
  Native, Flutter, Android, iOS, infrastructure), CI for GitHub or GitLab, git hooks, observability, logging,
  health, analytics, i18n, secrets.
- Build: task branch, test cases first, refactor, performance, migrations,
  feature flags, handoff between sessions.
- Verify: test automation, run and self-heal, load, resilience,
  accessibility, privacy, compliance, definition of done, stack-aware
  review, gate audit, traceability, the report.
- Ship and operate: merge request or pull request, release, package
  publish, store submission, experiments, VAPT, dependencies; runbooks,
  incidents, postmortems, on-call, cost, the handover pack.
- Seven subagents (reviewer, verifier, security auditor, explorer, test
  writer, doc writer, critic), hooks over one guard script, and the files every
  repository commits.

The complete map, one skill for every row, is
[docs/WORKFLOW.md](docs/WORKFLOW.md). The handbook is a site with the four
task flows (greenfield, bug fix, feature addition, inherited codebase), every stage, and a page
per skill with when to use it and where it fits. It is built from
`site/` (`make site`) and deployed to Vercel by the `docs` GitHub workflow
(or the `handbook:vercel` job on a GitLab mirror); see
[docs/INSTALL.md](docs/INSTALL.md#the-handbook-site-on-vercel). On a
GitLab host without Vercel, the `pages` job publishes it to GitLab Pages,
and `make wiki` exports the same docs and the four flows as wiki pages
(see [docs/INSTALL.md](docs/INSTALL.md#the-docs-as-wiki-pages)).

## Other harnesses

The standard lives in AGENTS.md, the gate in the Makefile and CI, and the
guard logic in `plugins/bearing/bin/brg-guard`, so it does not depend on
one harness.
`harness-setup <id>` (or `~/bearing/plugins/bearing/bin/brg-harness <id>` from the
repository) writes the rule files, the instruction pointer, the vendored
guard with hook adapters and the skills for Cursor, Codex, Gemini CLI,
Copilot, OpenCode, Windsurf, Cline, Zed and Kiro. Install the kit on such
a machine with `bash ~/bearing/install.sh --no-claude`. What each harness
enforces is in
`plugins/bearing/skills/harness-setup/references/harness-matrix.md`.

## Configuration

One file, `~/.config/bearing/bearing.env` (mode 600, never inside a
repository): the tracker and its credentials, the git host, the kit
remote, the org id. Every key is explained in
[docs/INSTALL.md](docs/INSTALL.md) and the adapters in
[docs/TRACKERS.md](docs/TRACKERS.md).

## Out of scope

The kit has no stack lane for Unity, embedded firmware, .NET, Rust or
Kotlin Multiplatform. On those, `tech-decision` still runs the technology
choice, the universal rules still apply, and the repository's own
conventions stand in for the stack skill.

## Licence and contributing

MIT; see [LICENSE](LICENSE). Third-party packs the installer can add keep
their own licences ([docs/THIRD_PARTY.md](docs/THIRD_PARTY.md)).
Contributions follow [CONTRIBUTING.md](CONTRIBUTING.md); report a
vulnerability privately as [SECURITY.md](SECURITY.md) describes; conduct
per [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

## Documents

- [site/](site/): the handbook site (`make site`; the `docs` workflow
  deploys it to Vercel; on GitLab the `pages` job or `make wiki`).
- [devguide/](devguide/): the developer guide, how Bearing works inside, for
  the people who change it (`make devguide`; the `docs` workflow deploys
  it, see [docs/INSTALL.md](docs/INSTALL.md#the-developer-guide-on-vercel)).
- [docs/INSTALL.md](docs/INSTALL.md): install, profiles, configuration,
  other harnesses, upgrade, uninstall, troubleshooting.
- [docs/WORKFLOW.md](docs/WORKFLOW.md): every stage, the skill it runs,
  a worked example.
- [docs/SKILLS.md](docs/SKILLS.md): every Bearing skill explained.
- [docs/TRACKERS.md](docs/TRACKERS.md): the tracker adapters and the env file.
- [docs/THIRD_PARTY.md](docs/THIRD_PARTY.md): what comes from where, per profile.
- [docs/REPO_LAYOUT.md](docs/REPO_LAYOUT.md): what each repository file is for.
- [CHANGELOG.md](CHANGELOG.md), [CONTRIBUTING.md](CONTRIBUTING.md),
  [SECURITY.md](SECURITY.md), [NOTICE.md](NOTICE.md).

## Develop the kit

```bash
make check       # the gate: validate (marketplace and each plugin), lint, plugin sizes, tests, docs freshness
make docs        # regenerate SKILLS.md, WORKFLOW.md, the handbook, the template maps
make test        # the test suite under tests/
/bearing:new-skill <name>   # add a skill the right way
```

CI runs on GitHub Actions: `.github/workflows/ci.yml` (the checks, a
scaffold of every stack that builds on a Linux runner, bash 3.2 and macOS)
and `.github/workflows/docs.yml` (deploys the handbook and the developer
guide to Vercel). `.gitlab-ci.yml` is the twin of both for a GitLab
mirror.

The repository is the marketplace: `.claude-plugin/marketplace.json`
lists `plugins/bearing`, `plugins/bearing-backend` and
`plugins/bearing-apps`. Evals (`evals/`), tests (`tests/`), the sites and
the repository's own tools (`bin/`: generators, lints, the eval
harnesses) sit outside every plugin and never ship. `make
lint-plugin-size` keeps each plugin under 512 files and every non-image
file under 256 KiB.

Version in `VERSION`, every `plugins/*/.claude-plugin/plugin.json` and
`.claude-plugin/marketplace.json`, in lockstep (`make lint-version`); changes in
`CHANGELOG.md`. Commits follow the same rules as every repository on the
Bearing standard: Conventional, no AI attribution, no em dashes.
Contributions come as pull requests on GitHub; the flow is in
[CONTRIBUTING.md](CONTRIBUTING.md).
