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

## Quickstart

Each step ends with one line you can check.

1. Clone and install.
   ```bash
   git clone <your fork url> ~/bearing
   bash ~/bearing/install.sh
   ```
   Last line: `install.sh: N installed, M already present, K skipped, 0 failed`.
2. Configure `~/.config/bearing/bearing.env` (the installer wrote it with
   placeholders; `BEARING_TRACKER=none` is valid), then check it:
   ```bash
   ~/bearing/bin/brg-tracker config
   ```
   First line: `tracker: none (from file)` or your tracker's name.
3. Restart the harness, then in any repository run `doctor`.
   Last line: `brg-doctor: N checks, 0 missing, M optional`.
4. Put a repository on the standard: `new-repo go-api InvoiceService`
   for a new one, `onboard-repo --stack react-web` for an existing one.
   Last line: `brg-scaffold: N files written to <dir> (...)` or
   `brg-adopt: N files in standard (...): added A, kept K, conflicts 0 (core.hooksPath set)`.
5. Start a task: `start-task TASK-142 InvoiceTotals`.
   Last line: `Next: <skill or action>`. From there `workflow` names
   each next step.

## How the skills are used

You do not have to remember skill names. Ask in your own words ("write
the PRD for this brief", "is this branch ready for review") and Claude
loads the matching skill. Every skill can also be called directly as
`/bearing:<name>`, for example `/bearing:test-run` or
`/bearing:merge-request`. Names say the job (`definition-of-done`, not
`dod`) because on a machine with hundreds of skills Claude Code may list
some by name only; see
[docs/INSTALL.md](docs/INSTALL.md) for keeping the listing lean.

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
- Repository: scaffold or adopt for seven stacks (more lanes are being
  added), CI for GitLab or GitHub, git hooks, observability, logging,
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

The complete map with the alternate for every row is
[docs/WORKFLOW.md](docs/WORKFLOW.md). The handbook is a site with the four
task flows (greenfield, bug fix, feature addition, inherited codebase), every stage, and a page
per skill with its verdict against the best alternative; it is built from
`site/` (`make site`) and published by the `pages` job where the git host
serves GitLab Pages, and by `handbook:vercel` to Vercel when its variables
are set (see [docs/INSTALL.md](docs/INSTALL.md#the-handbook-site-on-vercel)).
`make wiki` also exports the same docs
and the four flows as wiki pages (see [docs/INSTALL.md](docs/INSTALL.md#the-docs-as-wiki-pages)).

## Other harnesses

The standard lives in AGENTS.md, the gate in the Makefile and CI, and the
guard logic in `bin/brg-guard`, so it does not depend on one harness.
`harness-setup <id>` (or `~/bearing/bin/brg-harness <id>` from the
repository) writes the rule files, the instruction pointer, the vendored
guard with hook adapters and the skills for Cursor, Codex, Gemini CLI,
Copilot, OpenCode, Windsurf, Cline, Zed and Kiro. Install the kit on such
a machine with `bash ~/bearing/install.sh --no-claude`. What each harness
enforces is in `skills/harness-setup/references/harness-matrix.md`.

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

- [site/](site/): the handbook site (`make site`; the `pages` job publishes it
  where GitLab Pages is enabled, `make wiki` exports the docs to the wiki).
- [devguide/](devguide/): the developer guide, how Bearing works inside, for
  the people who change it (`make devguide`; `devguide:vercel` publishes it,
  see [docs/INSTALL.md](docs/INSTALL.md#the-developer-guide-on-vercel)).
- [docs/INSTALL.md](docs/INSTALL.md): install, profiles, configuration,
  other harnesses, upgrade, uninstall, troubleshooting.
- [docs/WORKFLOW.md](docs/WORKFLOW.md): every stage, one main skill, the
  alternates, a worked example.
- [docs/SKILLS.md](docs/SKILLS.md): every Bearing skill explained.
- [docs/TRACKERS.md](docs/TRACKERS.md): the tracker adapters and the env file.
- [docs/THIRD_PARTY.md](docs/THIRD_PARTY.md): what comes from where, per profile.
- [docs/REPO_LAYOUT.md](docs/REPO_LAYOUT.md): what each repository file is for.
- [CHANGELOG.md](CHANGELOG.md), [CONTRIBUTING.md](CONTRIBUTING.md),
  [SECURITY.md](SECURITY.md), [NOTICE.md](NOTICE.md).

## Develop the kit

```bash
make check       # the gate: validate, lint, tests, docs freshness
make docs        # regenerate SKILLS.md, WORKFLOW.md, the handbook, the template maps
make test        # the test suite under tests/
new-skill <name>   # add a skill the right way
```

Version in `VERSION`, `.claude-plugin/plugin.json` and
`.claude-plugin/marketplace.json` (`make lint-version`); changes in
`CHANGELOG.md`. Commits follow the same rules as every repository on this
standard: Conventional, no AI attribution, no em dashes.
