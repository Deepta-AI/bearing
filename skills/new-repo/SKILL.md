---
name: new-repo
description: 'Creates a new repository for one stack with Makefile, CI, git hooks, CLAUDE.md, AGENTS.md, rules, MR templates and docs in place. Use when asked to "create a repo", "scaffold a service" or "start a new project".'
argument-hint: "<stack> <PascalName> [--dir path] [--module <path>] [--tracker <PREFIX>] [--lead @user] [--group @group]"
allowed-tools: Read, Grep, Glob, Skill, Bash(bash *bin/brg-scaffold *), Bash(ls:*), Bash(make:*), Bash(git status:*)
---

# new-repo

Everything deterministic is done by `bin/brg-scaffold`. This skill gathers
the inputs, runs it, runs the gate, and reports. It needs nothing from
the target directory; the scaffold and its templates ship with the plugin.

## Inputs

- stack: looks in `$1`; if absent, asks (step 1); never inferred.
- name: looks in `$2`; if absent, asks for a two to four word PascalCase
  name.
- module path (go-api): `--module`; if absent, one question with the
  default `example.com/<slug>`; a default that was accepted is listed
  under Not done as a placeholder.
- tracker prefix: `--tracker`; if absent, `BEARING_TASK_ID_PREFIX` from the
  environment or `~/.config/bearing/bearing.env`; if unset, no prefix
  (branches carry any `[A-Z][A-Z0-9]*-<n>` id or `NOTASK-<n>`).
- lead, group: `--lead`, `--group`; if absent, `@lead`, `@group`, each
  listed under Not done to fill.
- scaffold and templates: `${CLAUDE_PLUGIN_ROOT}/bin/brg-scaffold` and
  `${CLAUDE_PLUGIN_ROOT}/templates/repo/`; both ship with the plugin.
  If the plugin root is unset, stop: "install Bearing (`bash install.sh`)
  and rerun".
- target directory: `--dir`, else `./<slug>`; must be empty or absent.
  If not, ask once for another path, or point at `onboard-repo` when the
  user means the existing repository.
- decisions: accepted ADRs under `docs/adr/` of the target (none for a
  new repository); the rest are asked through the Decisions first
  protocol below; the ones the user answers become the first ADRs.

## Steps

**Decisions first.** Before building, run `tech-decision` for the keys
stack (backend language, frontend, mobile), database, api style, orm,
tracker, org id. `tech-decision` asks only about the keys this task needs that no
accepted ADR, the request or the code already settles, one question at
a time, and records only what the user decides; a key still
awaiting an answer follows
${CLAUDE_PLUGIN_ROOT}/skills/tech-decision/references/decision-protocol.md.

1. Ask for the stack; never infer it silently. Ask what the repository is
   for in one sentence, then present the ids `react-web`, `next-app`,
   `node-api`, `go-api`, `go-cli`, `python-api`, `python-cli`,
   `data-pipeline`, `react-native`, `flutter-app`, `android`, `ios`,
   `infra` with one line each and a recommendation with reasons (a service
   in a Go shop: go-api; a data or GenAI service: python-api; a
   command-line tool with no server or database: go-cli, or python-cli
   where the team writes Python; a forms-and-lists app for both
   phones with a React web team: react-native; camera, Bluetooth or peak
   performance: android and ios; SEO-heavy web: react-web with the
   Next.js note). Wait for the answer. Then the remaining decisions from
   the list above through `tech-decision`.
2. Resolve the name: PascalCase, no spaces. The slug is derived. For
   go-api, ask for the module path if not given, offering
   `example.com/<slug>` as the default.
3. Run `bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-scaffold" <stack> <Name> [flags]`.
   It refuses a non-empty target; do not delete anything to make room.
4. Read the summary line: `N files written ... K files with unfilled
   placeholders`. K must be 0; if not, open those files and fill them.
5. Run `make check` in the new repository. For react-web and python-api,
   install dependencies first (`make setup`). For android, ios and
   react-native on a machine without the toolchain, the Makefile prints
   SKIPPED lines; report them verbatim. Without `make` on the machine,
   print the stack's native test command and say the gate was not run.
6. Fill the CLAUDE.md snapshot with anything the scaffold could not know
   (what the service talks to, sibling repositories).
7. Print the output contract below, then the four report headings (Changed, Verified, Not done, Noticed).
   Under Not done: the first commit, the GitLab project creation,
   CODEOWNERS usernames, and CI variables, each with the exact command or
   click path for the engineer.

## Output contract

```
## New repo: <Name> (<stack>) at <dir>
Decisions: N decided, S settled, A awaiting the user, D deferred (ADRs: docs/adr/0001..)
brg-scaffold: N files written, K with unfilled placeholders (must be 0)
Gate: make check: passed | SKIPPED lines: <verbatim> | not run (no make)
Tracker prefix: <PREFIX> | none   Module: <path> | placeholder   Lead, group: <handles> | placeholders
Not done: first commit (<command>), remote project creation, CODEOWNERS handles, CI variables
```

## Gotchas

- The scaffold never commits and never pushes. Print
  `git add -A && git commit -m "chore: scaffold <Name> from bearing"` for
  the engineer.
- `core.hooksPath` is set by the scaffold; `make setup` sets it again for
  the next clone. Both are idempotent.
- The android and ios skeletons need their toolchains (JDK plus Android
  SDK, Xcode) to build; on Linux the gate reports what it skipped.
- Placeholders left by a missing flag (`@lead`, the example module path)
  are listed, never silently shipped.
