---
name: new-repo
description: 'Creates a new repository for one stack with Makefile, CI, git hooks, CLAUDE.md, AGENTS.md, rules, MR templates and docs in place. Use when asked to "create a repo", "scaffold a service" or "start a new project".'
argument-hint: "<stack> <PascalName> [--dir path] [--module <path>] [--tracker <PREFIX>] [--lead @user] [--group @group]"
allowed-tools: Read, Grep, Glob, Edit, Write, Skill, Bash(bash *bin/brg-scaffold *), Bash(ls:*), Bash(make:*), Bash(cp:*), Bash(mkdir:*), Bash(git status:*), Bash(git log:*), Bash(git branch:*), Bash(git init:*), Bash(git config:*), Bash(git check-ignore:*), Bash(go:*), Bash(gofmt:*), Bash(python3:*), Bash(uv:*), Bash(pytest:*), Bash(ruff:*)
---

# new-repo

A new repository is judged by whether it fits where it lands: the group's
registry, its sibling repositories, its CI runners and its written rules.
A small repository that matches its siblings and passes its own gate on
this machine beats a rich skeleton built on the kit's defaults that fails
on the group's runners. So this skill reads the surroundings first; the kit
scaffold (`bin/brg-scaffold`) is the base only where there is nothing to
match, and its output is always conformed before it is reported.

## Inputs

- The request: purpose, stack, owner. "Go, like <sibling>" settles the
  stack; a stack nothing settles is asked (step 2), never guessed.
- The surroundings (step 1): the parent directories up to the workspace
  root, the registry of repositories if one exists (a `repos.yaml`, a
  manifest, a README list), conventions docs, ADRs with their Status, and
  the nearest sibling of the same kind and language.
- The machine: the installed toolchains, whether the network may be used,
  what the module or package cache already holds.
- Flags, when given, win over what the survey derives: `--dir`,
  `--module`, `--tracker`, `--lead`, `--group`, `--host`. Otherwise
  `BEARING_TASK_ID_PREFIX` and `BEARING_GIT_HOST` from the environment or
  `~/.config/bearing/bearing.env` apply only where the survey found
  nothing; that file's host default is `both`, which is wrong for a
  one-host group.
- Scaffold and templates: `${CLAUDE_PLUGIN_ROOT}/bin/brg-scaffold` and
  `${CLAUDE_PLUGIN_ROOT}/templates/repo/`. If the plugin root is unset,
  stop: "install Bearing (`bash install.sh`) and rerun".
- Target directory: beside the siblings (where the registry's clone step
  puts repositories), else `./<slug>`; empty or absent. If not, ask once
  for another path, or point at `onboard-repo` when the user means the
  existing repository.
- Decisions: accepted ADRs in the workspace settle their keys; a
  superseded ADR settles nothing.

## Steps

**Decisions first.** Before building, run `tech-decision` for the keys
stack, database, api style, orm, tracker and org id. Most are settled by
the request, an accepted ADR or the siblings; `tech-decision` asks only
about the rest, one question at a time, and records only what the user
decides; a key still awaiting an answer follows
${CLAUDE_PLUGIN_ROOT}/skills/tech-decision/references/decision-protocol.md
(recorded as Proposed, never as decided).

1. **Survey before writing anything.** Record each fact with its source.
   - Workspace: `ls -a` at the root, the registry, the conventions, every
     ADR's Status line.
   - Nearest sibling of the same kind and language: its version pins
     (`go` line in go.mod, `requires-python`, ruff and mypy targets), CI
     image, Dockerfile, Makefile target names, CODEOWNERS form,
     `.gitignore`, health routes, config and port idiom, test style, and
     the commit and branch form from its history (`git log --format=%s -20`
     run inside it) and README.
   - In-flight claims: in the workspace repository, `git branch -r` and
     `git log --all --oneline -- <registry file>`. An unmerged branch that
     registers a repository has taken its name and port.
   - Machine: `go version`, `python3 --version` and which other
     interpreters exist (`ls /usr/bin/python3.*`), `uv --version`; whether
     network installs are allowed.
   - Sensitive data nearby (exports, dumps): note the path and the group's
     rule for it. Do not open it to learn its shape; use a documented
     sample or the rule's description.

2. **Derive every input; ask only what is still open.**
   - Name: by the group's naming rule, unique against every registry entry,
     retired and archived ones included (the remote project usually still
     exists). A clash is reported, with reuse of the archived project
     offered as the alternative.
   - Allocated values (port, id range): computed from the registry by its
     written rule, retired entries included, then checked against the
     in-flight branches. When a branch has taken the value, take the next
     one and name the branch in the report. A "next free" note that
     disagrees with the rule is stale: say so, and correct it in the same
     change when it lives in the registry's repository.
   - Toolchain floor: the lowest of the conventions' pin, the siblings'
     pins, the CI image and the local toolchain. The new repository pins
     exactly that (`go 1.x.0`, `requires-python = ">=3.x"`, ruff
     `target-version`, mypy `python_version`, CI and Docker images).
   - Module path, owners, CODEOWNERS line, CI host, commit and branch
     form, ignore rules for sensitive files: from the conventions, else
     the siblings.
   - Unattended, pick the recommended option for anything open and record
     the question and the choice.

3. **Build the base.**
   - A sibling of the same stack exists: write the repository in its
     shape (same Makefile targets, CI layout and image, Dockerfile
     pattern, config idiom, test style) with only what this repository
     needs today: entrypoint, config with the derived defaults, health
     endpoints for a service, one test per behaviour it has. Add no
     dependency the request or the siblings do not need. Offline, add
     none you cannot fetch now; name it as the next step instead.
   - The kit's harness files (AGENTS.md, CLAUDE.md, `.claude/`,
     `.githooks/`): scaffold into a scratch directory with the derived
     flags and copy those four across, then conform them (step 4).
   - No sibling to match: `bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-scaffold" <stack> <Name> --dir <dir> --host <gitlab|github> --tracker <PREFIX> --module <path> --lead <@handle> --group <@group>`.
     Stack ids: `react-web`, `next-app`, `node-api`, `go-api`, `go-cli`,
     `python-api`, `python-cli`, `data-pipeline`, `react-native`,
     `flutter-app`, `android`, `ios`, `infra`. Offline, set
     `GOPROXY=off UV_OFFLINE=1 npm_config_offline=true` first; its
     lockfile step then fails harmlessly. It refuses a non-empty target;
     never delete anything to make room.
   - The new directory is its own git repository (`git init -b main`;
     the scaffold does this itself).

4. **Conform whatever a template chose.** Kit templates track the newest
   releases and generic defaults; none of that survives unchecked.
   - Pins: every go.mod (tools/ included), Dockerfile `FROM`, CI version
     variables, `requires-python`, ruff and mypy targets, any
     `uv python install` line, set to the floor. A lockfile resolved for
     another interpreter is re-resolved for the floor or removed, and CI
     then must not run a locked or frozen install against a missing file.
   - Dependencies: each must build on the floor toolchain. Template pins
     chosen for a newer toolchain often need it (Go modules raise their
     own `go` line). One that cannot be verified here is removed with the
     code that needs it, and listed as a next step.
   - Commit rules: set `COMMIT_RE`, `BRANCH_RE` and `TASK_ID_RE` in
     `.githooks/lib.sh` and any CI commit or branch job to the group's
     form, then feed a real subject from the sibling's history through
     the hook. If the group's form cannot be expressed, drop the hooks
     (`git config --unset core.hooksPath`) and say so.
   - Host: no `.github/` in a GitLab-only group, no `.gitlab-ci.yml` in a
     GitHub-only one.
   - Placeholder sweep: grep the new repository for `example.com`, `8080`,
     `@lead`, `@group`, `@engineering`, `TODO`, `CHANGEME` and
     `__[A-Z_]+__`. Each hit is filled from the survey or removed; a
     deploy job aimed at a made-up URL is removed, not left to fail later.
   - Features no sibling has (tracing, metrics, an ORM, auth) are dropped
     unless the request asks for them, and named under Noticed.

5. **Register in the same change.** Add the registry entry, correct any
   stale note found in step 2, and run the registry's own check
   (`make check` at the workspace root); read its count, not only its
   exit code.

6. **Gate, as delivered, on this machine.**
   - `make check` in the new repository on the floor toolchain
     (`GOTOOLCHAIN=local` for Go; for Python the floor interpreter when it
     is installed, `uv run --python 3.x pytest` or that interpreter's
     `-m pytest`). State which interpreter or toolchain ran; a pass on a
     newer one says nothing about the floor.
   - Break one assertion once and see the gate fail, then restore it. A
     gate that passes on zero tests or zero files is fixed to fail.
   - `git check-ignore -v` on a made-up sensitive filename and on a
     fixture path, when the group has ignore rules for such data.
   - Claim a pass only for what ran. A step that needs the network is
     "not run" with the reason, and the repository's gate is then not
     "passed".
   - `git status` in the new repository, the workspace and each sibling:
     nothing committed, siblings untouched.

7. **Docs that describe what exists.** README and CLAUDE.md state the
   derived facts with their sources (port, owners, pins, siblings) and
   what the code does today. Planned behaviour sits under a heading that
   says planned; what the service talks to is written only as the request
   or the workspace states it, otherwise as an open question.

8. Print the output contract, then Changed, Verified, Not done, Noticed.

## Output contract

```
## New repo: <name> (<stack>) at <dir>
Base: shape of <sibling> (+ kit harness files) | brg-scaffold <stack>
Derived: name, module, port, owners, host, pins, commit form (source of each)
Registry: <entry added>; check: <its count line> | not a registry here
Gate: <command> on <toolchain>: passed (<counts>) | failed: <why> | not run: <why>
Not done: first commit (<command in the group's form>), remote project, <the rest>
```

## Gotchas

- A "next free" note, a README example or a superseded ADR is a claim;
  the registry's data under its written rule, and the accepted ADR, win.
- Two changes that each take "the next" value collide at merge. Unmerged
  branches of the registry are part of the registry.
- A `go` line above the local toolchain fails before anything compiles
  under `GOTOOLCHAIN=local`; changing the CI image does not fix go.mod.
- `python3` on PATH is often not the interpreter CI runs, and a test run
  on a newer one hides syntax and standard library the floor lacks.
- Real data (bank exports, customer dumps) never enters the repository, a
  fixture, a derived scratch file or the transcript. Fixtures are made up;
  the tool is never run on the real file to try it.
- Nothing is committed or pushed. Print the first commit and branch in the
  group's form, the registry change as its own commit, and the remote
  project creation as a click path.
- The android and ios skeletons need their toolchains; on Linux the gate
  prints SKIPPED lines, reported verbatim.
