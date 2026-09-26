---
name: ci-pipeline
description: 'Generates or refreshes the CI pipeline for the stack (GitLab CI, GitHub Actions or both), every job a make target, deploys manual. Use when asked to "add CI", "set up the pipeline", "fix the pipeline" or "add a CI job".'
argument-hint: "[--stack <id>] [--host gitlab|github|both] [--refresh]"
allowed-tools: Read, Write, Edit, Grep, Glob, Skill, Bash(ls:*), Bash(git status:*), Bash(git diff:*), Bash(git remote:*), Bash(python3 -c:*), Bash(make -n:*), Bash(bash *bin/brg-kit-paths*)
---

# ci-pipeline

The Makefile is the contract: every CI job calls a `make` target the
engineer can run locally. The templates live in the stack skills, under
the plugin root, so they are present whenever this skill runs.

## Inputs

- stack: `--stack`; if absent, detected from `go.mod` (go-api, or go-cli
  when the repository has no `Dockerfile`), `pyproject.toml` with `dbt` or
  `airflow` (data-pipeline), with `[project.scripts]` and no `fastapi`
  (python-cli), else (python-api), `package.json` with `next` (next-app), `react`
  (react-web), `expo` (react-native) or `fastify` (node-api),
  `pubspec.yaml` (flutter-app), `build.gradle.kts` (android),
  `Package.swift` or `*.xcodeproj` (ios), `*.tf` (infra); more than one
  match or none: ask one question.
- host: `--host gitlab|github|both`; if absent, `BEARING_GIT_HOST` from the
  environment or `~/.config/bearing/bearing.env`; if absent, from
  `git remote get-url origin` (`github.com` is github, a url containing
  `gitlab` is gitlab); if there is no remote, `both`. Say which.
- templates: `<skill dir>/templates/.gitlab-ci.yml` and
  `<skill dir>/templates/.github/workflows/ci.yml`, where the skill
  directory is what `bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-kit-paths" --skill <skill>`
  prints and the skill is `bearing-apps:react` (react-web),
  `bearing-apps:nextjs` (next-app), `bearing-backend:node` (node-api),
  `bearing-backend:go` (go-api; `templates-cli/` for go-cli),
  `bearing-backend:python` (python-api; `templates-cli/` for python-cli),
  `bearing-backend:data-pipeline` (data-pipeline), `bearing-apps:react-native`,
  `bearing-apps:flutter`, `bearing-apps:android`, `bearing-apps:ios`,
  `bearing-backend:infra`. Referenced by path so one file per stack and
  host stays the source; a missing file stops with the path, and a
  missing plugin stops with the line brg-kit-paths prints (the plugin
  to install).
- repo name and slug: the CLAUDE.md snapshot (`Repository:` line); if
  absent, the basename of `git remote get-url origin`; if absent, the
  directory name.
- Makefile targets: `make -n <target>` per target the pipeline calls; a
  missing target is not a stop: add a thin target that runs the stack's
  native command (create a minimal Makefile when there is none), say so,
  and say the fuller Makefile comes from `new-repo` or `onboard-repo`.
- ci and delivery decisions: accepted ADRs; if absent, the Decisions
  first protocol below; if the user defers, the template's defaults
  (manual, unwired deploy jobs) and the report says so.
- PyYAML: optional; without it the YAML is read by eye and the job count
  is marked "unparsed".

## Steps

**Decisions first.** Before building, run `tech-decision` for the keys ci,
delivery. `tech-decision` asks only about the keys this task needs that no
accepted ADR, the request or the code already settles, one question at
a time, and records only what the user decides; a key still
awaiting an answer follows
${CLAUDE_PLUGIN_ROOT}/skills/tech-decision/references/decision-protocol.md.

1. Resolve the stack and locate the template as in Inputs.
2. For each host in scope (`.gitlab-ci.yml` for gitlab,
   `.github/workflows/ci.yml` plus `.github/PULL_REQUEST_TEMPLATE.md` from
   `${CLAUDE_PLUGIN_ROOT}/templates/repo/.github/` for github): if the
   file does not exist, copy the template, substitute `__REPO_NAME__` and
   `__REPO_SLUG__` from Inputs, done for that host.
3. If it exists and `--refresh` is given: diff the stage or job list, the
   `branch-name` and `commits` jobs, and the security jobs against the
   template. Add what is missing; never remove a job the repository added.
   Show the diff before writing.
4. If it exists without `--refresh`: report the gaps against the template
   (missing stages, missing governance jobs, a job that does not call
   `make`) and stop. Let the engineer choose `--refresh`.
5. Verify every `make` target the file references exists: `make -n <target>`
   for each. Missing targets get the fallback in Inputs; list them.
6. Parse each YAML (`python3 -c "import yaml,sys; yaml.safe_load(open(sys.argv[1]))" <file>`
   when PyYAML is present; otherwise a careful read) and count the jobs.
   Print `N jobs, M stages` per file; zero jobs is a failure.
7. Security review of the GitHub workflows, when github is in scope and
   `.github/workflows/` holds at least one file (the ones written here
   and the ones the repository already had). When the
   `gha-security-review` skill is installed, load it through the Skill
   tool and follow it over `.github/workflows/*.yml` and any local
   `action.yml`. It traces attacks an outside contributor can run (pwn
   requests, expression injection, comment commands, credential reach,
   unpinned third-party actions in privileged jobs) and reports only
   what it can exploit; this skill writes and refreshes the pipeline and
   does not judge those paths itself. When any step `uses:` an AI agent
   action (`anthropics/claude-code-action`, `openai/codex-action`,
   `google-github-actions/run-gemini-cli`,
   `google-gemini/gemini-cli-action`, `actions/ai-inference`), also
   load `agentic-actions-auditor` for the prompt injection vectors. A
   finding in a file this run wrote is fixed in the file before the
   report, and the kit template it came from is named as a finding for
   the kit; a finding in a file the repository owns is reported, not
   edited. When `gha-security-review` is not installed, write "not
   reviewed (gha-security-review not installed)" in the report; the
   agentic check still runs when its skill is present. Zero workflow
   files read with github in scope is a failure of the review, not a
   clean result. Neither skill covers `.gitlab-ci.yml`; the report says
   the GitLab pipeline had no pack review.
8. Report: what changed per host, which CI variables or secrets the
   pipeline expects (`CI_REGISTRY_*` and `GITHUB_TOKEN` are automatic;
   deploy jobs need wiring and, on GitHub, an environment with required
   reviewers), which Makefile targets were added as thin wrappers, and
   that the deploy jobs are placeholders until wired.

## Output contract

```
## CI: <stack>, host <gitlab | github | both> (<source of the host>)
.gitlab-ci.yml: created | refreshed | gaps reported | not in scope
.github/workflows/ci.yml: created | refreshed | gaps reported | not in scope
Jobs: N   Stages: M per file (parsed | unparsed, PyYAML absent)
Make targets referenced: N (missing: K, thin wrappers added: T)
Deploy jobs: manual, unwired (exit 1 until wired)
Variables expected: <names>
Workflow security: W workflow files reviewed, F findings (AI actions: A, agentic findings: G) | not reviewed (<reason>) | not in scope
```

## Gotchas

- Deploy jobs are deliberately manual and unwired. A pipeline that deploys
  on merge is a decision for the lead, recorded in an ADR, not a default.
- iOS and react-native iOS builds need a macOS runner or EAS cloud; the
  template marks those jobs and they fail with a message until one exists.
- On GitHub the two-approval rule is a branch protection setting, not a
  workflow step; the workflow header says so. Say it in the report too.
- Never add an AI review job to CI. Reviews run locally (`branch-review`).
- A thin `make` target that only wraps `go test ./...` keeps the contract
  (CI calls make) but not the standard's gate; the report says which
  targets are thin.
