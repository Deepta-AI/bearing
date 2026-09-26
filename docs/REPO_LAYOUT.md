# What every repository on the Bearing standard carries, and why

Installed by `new-repo` (new) or `onboard-repo` (existing). Committed
unless marked ignored. Which host-dependent set a repository gets follows
`BEARING_GIT_HOST` in `~/.config/bearing/bearing.env` (`gitlab`, `github` or
`both`; `onboard-repo` infers it from the origin remote when unset).

| File | Why it exists |
| --- | --- |
| `AGENTS.md` | The engineering standard every agent reads, about 120 lines: ground rules, task flow, git and change requests, definition of done, report shape, the generated skills map, the list of path-scoped rules. One file, so Claude Code, Cursor, Codex and Gemini CLI read the same thing. |
| `CLAUDE.md` | Claude Code mechanics. The full contents of every file here are on the handbook's Default files page. Its first line is `@AGENTS.md`, which imports the standard into every session. Then a snapshot under twenty lines (stack, git host, tracker, trunk), the same generated skills map, hygiene, and the "things Claude gets wrong here" list. Under 80 lines. |
| `.claude/settings.json` | Least-privilege permissions derived from the guard's verb table: read-only and build tools allowed; commits and dependency changes ask; push, history rewrite, deploy tools, secrets and lockfile reads denied. Also names the `bearing` marketplace and the enabled plugins so a fresh clone prompts the developer to install. Denies the third-party skills kept off work repos. |
| `.claude/rules/*.md` | Rules. `code.md` (source files), `database.md` (migrations, SQL, repositories) and `testing.md` (test files) carry a `paths:` list and load only when a matching file is touched; `observability.md`, `analytics.md` and `security.md` have none and load in every session. Plus the stack's own rules file (`react.md`, `nextjs.md`, `node.md`, `go.md`, `python.md`, `data.md`, `react-native.md`, `flutter.md`, `android.md`, `ios.md` or `infra.md`). Zero cost when irrelevant. |
| `.claude/settings.local.json` | Personal overrides. Git-ignored. May add permissions; must not loosen the deny list. |
| `.bearing/company.json` | Who the repository belongs to, written by `company-attribution`; the LICENSE, NOTICE, CODEOWNERS and package metadata derive from it. |
| `.bearing/bin/brg-guard`, `.bearing/hooks/` | The vendored guard (stamped with the kit version; `doctor` compares) and the hook adapters for the harness in use, written by `harness-setup`. Committed. |
| `.bearing/state/` | Session handoff files written by `session-handoff`, read back on the next start. Git-ignored. |
| `.githooks/` | commit-msg (Conventional Commit, task id, no AI trailer, no em dash), pre-commit (format, lint, secret scan on staged files), pre-push (branch name typed by a person, no push to the trunk, `make check`). `core.hooksPath` points here; `make setup` sets it. |
| `Makefile` | The only entry point: `help setup dev check fix test doctor` plus stack targets. `make check` is the gate, prints `check: R gates run, S skipped`, and fails on any skip unless `BEARING_ALLOW_SKIP=1` is set locally. CI runs the same target. |
| `.gitlab-ci.yml` | GitLab set. Stages validate, lint, test, security, build, publish, deploy, verify. Every job calls a `make` target. Deploy jobs are manual and unwired until the lead decides. |
| `.gitlab/merge_request_templates/Default.md`, `.gitlab/issue_templates/` | GitLab set. The MR shape `merge-request` fills (summary, context, approach, how to test, verification, risk and rollback, checklist); Bug and Feature issue shapes. |
| `.github/workflows/`, `.github/PULL_REQUEST_TEMPLATE.md` | GitHub set. The same pipeline as a workflow, every job a `make` target; the PR shape `merge-request` fills. |
| `CODEOWNERS` | One peer and one lead approve; the standard's files need the lead. Handles come from `.bearing/company.json`. |
| `LICENSE`, `NOTICE.md` | The licence `company-attribution` chose (proprietary, Apache-2.0, MIT or custom) and the holder and contact. |
| `CONTRIBUTING.md` | The procedure: first day, a task start to finish, branches (trunk with `main` by default), reviews, documentation, sessions with the agent. |
| `SECURITY.md` | Reporting, the eight rules every change satisfies, incidents. |
| `docs/` | `adr/`, `design/`, `runbooks/`, `postmortems/`, `analytics/`, `security/`, and `templates/` that the doc skills fill. |
| `.scratch/` | Anything temporary. Git-ignored. Never `NOTES.md` at the root. |
| `.env.example` | Every configuration variable with a placeholder. `.env` itself is never committed and never read by the agent. |

Stack-specific files (lint configs, Dockerfile, compose, skeleton code and
the lockfile the scaffold creates when the toolchain is installed) come
from the stack skill's `templates/` and are listed in each stack skill's
SKILL.md.
