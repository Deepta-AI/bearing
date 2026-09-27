---
name: onboard-repo
description: 'Brings an existing repository onto the team conventions (Makefile, hooks, CLAUDE.md, rules) without overwriting; conflicts land beside the file. Use when asked to "onboard this repo" or "adopt the standard".'
argument-hint: "[--stack <id>] [--full]"
allowed-tools: Read, Write, Edit, Grep, Glob, Skill, Bash(bash *bin/brg-adopt *), Bash(bash *bin/brg-stacks*), Bash(bash .githooks/install.sh), Bash(mktemp -d:*), Bash(git clone:*), Bash(git status:*), Bash(git rev-parse:*), Bash(git log:*), Bash(git ls-files:*), Bash(git config --get:*), Bash(git remote get-url:*), Bash(git check-ignore:*), Bash(git diff:*), Bash(git init:*), Bash(ls:*), Bash(diff:*), Bash(make:*)
---

# onboard-repo

An existing repository already has conventions: a CI file that is the real
gate, a hook mechanism, a commit format, owners, a package manager, domain
rules someone wrote down after a bad day. Adoption adds the standard's
pieces *into* those conventions. The failure this skill exists to prevent
is the confident one: a pile of template files, a hook path that silently
turns the team's hooks off, a commit hook that rejects every subject in the
history, a `make check` that is green locally and red in CI.

Survey first, write second, prove last. Every file written is judged by
one question: does the team's current way of working still work, and does
the new piece actually run?

## Inputs

- repository: `git rev-parse --show-toplevel`; not a git repository: ask
  once whether to `git init`; on no, write the files and list hooks as not
  active under Not done.
- working tree: `git status --porcelain`. Dirty files are the engineer's
  work in progress: never stash, revert, format or commit them; edit
  around them and list them in the report. Run the gate with them present.
- scope: what the request names (AGENTS.md, CLAUDE.md, `make check`,
  hooks, CODEOWNERS, rules). `--full`, or "adopt the whole standard", adds
  the rest of the standard's files, each still subject to the survey.
  Nothing outside scope is added.
- host: evidence in the repository wins: `git remote get-url origin`,
  `.gitlab-ci.yml` or `.gitlab/`, `.github/`. `BEARING_GIT_HOST` in the
  user's config is a default for new repositories and never adds `.github/`
  to a GitLab repository or `.gitlab/` to a GitHub one; pass `--host`
  explicitly.
- stacks: `bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-stacks"` lists every stack
  and its folder, up to three levels deep. `go.mod` with an HTTP server in
  `main` is `go-api`, otherwise `go-cli`; a `package.json` naming a server
  framework is `node-api`; a plain Node package with no framework has no
  stack template, which is fine: the survey drives the files, not the
  template. `--stack` overrides for the preview only.
- the standard: `${CLAUDE_PLUGIN_ROOT}/templates/repo/` and
  `${CLAUDE_PLUGIN_ROOT}/bin/brg-adopt`. If the plugin root is unset, stop:
  "install Bearing (`bash install.sh`) and rerun".

## Steps

**Decisions first, only for what the repository cannot answer.** Stacks,
host, package manager, commit format, hook mechanism and owners are read
from the repository, not decided. Run `tech-decision` only when the engineer
asks to change one of them. When the standard and the team disagree (commit
format, branch rules, push to main), the team's convention stays in force
and the standard's rule is offered as a Proposed change in the report.

1. **Survey.** Record each fact with the file or command that shows it;
   the rest of the run is checked against this list.
   - Gate: every CI job (`.gitlab-ci.yml`, `.github/workflows/*`): its
     working directory, commands, flags (markers, tags, `-race`),
     variables (top-level and per job: `TZ`, `LANG`, feature flags),
     services it starts, `allow_failure`, `rules`/`only`. Run each
     offline job's commands locally, exactly as written, and note the
     counts (files linted, tests run, skipped, deselected). A test that
     skips unless a job variable is set is the usual reason a local run
     reports fewer passes than CI.
   - Scripts CI calls (the test or lint script in package.json, a tox
     env): changing one changes CI, so treat it as a CI change.
   - Existing Makefile: its targets and what `check` really runs versus
     what the README or CONTRIBUTING claims it runs.
   - Hooks: `git config --get core.hooksPath`; `ls .git/hooks` for
     non-sample files and their first lines (pre-commit framework, Husky,
     lefthook, a hand-written hook); `.pre-commit-config.yaml`, `.husky/`,
     `lefthook.yml`, a `prepare` script, a `setup` target that sets the
     hook path. Tools the hooks call and whether they are installed here.
   - Conventions: commit format from CONTRIBUTING and from
     `git log --format=%s -30` (where they disagree, the history is what a
     hook meets tomorrow, and the disagreement is a finding); whether the
     team merges or commits straight to the default branch
     (`git log --merges --oneline -5` empty and linear history on main
     means direct commits); branch names in use.
   - Owners: which CODEOWNERS file the host reads. GitLab takes the first
     of `CODEOWNERS`, `docs/CODEOWNERS`, `.gitlab/CODEOWNERS`; GitHub the
     first of `.github/`, root, `docs/`. A new root file shadows the
     team's real one.
   - Ignore rules: `git check-ignore -v .claude/settings.json AGENTS.md`
     for every path you intend to add.
   - Package manager from the lockfile (`package-lock.json` or none: npm;
     `pnpm-lock.yaml`; `yarn.lock`; `uv.lock`; `poetry.lock`).
   - Tracked secrets: `git ls-files` for `.env*` (not `.example`), `*.pem`,
     `*.key`, credentials JSON. Note the path only; do not open it or
     print a value.
   - Agent notes already here: CLAUDE.md, AGENTS.md, `.cursorrules`,
     README sections with rules. Their rules are the most valuable text in
     the repository.
   - Doc claims that the survey falsifies (README test commands that fail
     from where it says to run them, "make check runs what CI runs", a
     setup step naming a file, service or target the repository does not
     have). Do not copy a false claim into AGENTS.md.
2. **Preview the standard, off the live repository.** Clone it into a
   temporary folder (`mktemp -d`, then `git clone -q . "$preview"`) and run
   `bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-adopt" --dir "$preview" --host <host>`
   (add `--stack <id>` for the main service's stack). Never run the adopter
   on the live repository: it writes every file in the standard, a root
   CODEOWNERS, and sets `core.hooksPath` when it is unset, which turns off
   whatever lives in `.git/hooks`. The preview is a menu, filled with this
   repository's name; take from it only what scope and the survey allow.
3. **Makefile and `make check`.** `make check` is CI's blocking jobs,
   run locally, in each job's directory, with each job's flags and
   variables. For each job, one target; `check` depends on the offline ones.
   - Keep every existing target and what it does; add prerequisites and
     targets, never replace a recipe wholesale.
   - Copy CI's variables into the targets (`TZ=UTC` in CI means the gate
     sets `TZ=UTC`; a suite that passes only under it is a finding to
     report, not a test or source file to edit).
   - A job that needs a service or secret (database, cloud credentials)
     gets its own target that fails loudly when its variable is missing,
     and stays out of `check`; `check` must pass on a laptop with no
     network, and the report says CI covers that job. A skipped gate that
     fails `check` makes the gate useless; one that passes silently hides
     it; print what was not run.
   - Fail on what CI fails on. A lister such as gofmt -l exits 0 while
     it lists unformatted files; CI wraps it in test -z, and so must the
     gate. Prove each check by making it fail once on a scratch file, then
     remove the file.
   - Commands use the repository's package manager and run where the
     module is (no `go test ./...` at a root with no `go.mod`).
   - The gate must pass on this machine with no arguments. Resolve tools
     the way the engineer's shell does: `python3` on PATH is often not the
     interpreter that has pytest (a newer system Python beside a
     `pytest` from another one). Pick the one that works here (for
     example the interpreter behind `pytest` on PATH), keep it
     overridable, and fail with the install line only when none has it.
   - Compare counts with CI's, including skips: a job variable that
     unlocks a test belongs in the target, or `check` passes on less.
   - The adopter's `check` recipe ends with a `.bearing/state/.check-passed`
     marker. Bearing's Stop gate reads it and nothing else does: keep it
     only when the team uses the Bearing plugin in this repository, with
     `.bearing/state/` ignored, and say so in Changed; otherwise leave it
     out.
   - Do not change CI unless asked. If you make CI call make targets, keep
     every job, image, service and variable.
4. **AGENTS.md and CLAUDE.md.** AGENTS.md is for this repository, not the
   template: what it is (each service, its language, its folder), the exact
   commands you proved in step 3, the commit format the team uses, the
   domain rules from existing notes, and the traps the survey found
   (append-only migrations, tracked secrets, the time-zone dependence).
   Take a rule from the template only when it holds for this stack
   (no TypeScript rules in a JavaScript repository, no pnpm in an npm one).
   CLAUDE.md: first line exactly `@AGENTS.md`; keep every line the team
   wrote, especially a "things Claude gets wrong" list.
5. **Hooks: one mechanism, the team's.** Add the standard's checks into the
   mechanism already in use, never beside it.
   - `core.hooksPath` set (Husky's `.husky`, a `tools/githooks`): leave
     it; call the new hook from that directory's hook, or add the new hook
     file there. The `setup` target and the live value must agree.
   - Pre-commit framework in `.git/hooks`: leave `core.hooksPath` unset
     and `.pre-commit-config.yaml`'s existing hooks untouched; a new check
     goes in as a `repo: local` hook (a new hook type needs
     `pre-commit install --hook-type <type>` per clone: say so), or stays
     inactive with the wiring step in the report.
   - Nothing in place: `.githooks/` with `bash .githooks/install.sh`.
   - Fit every hook you write, active or not, to the survey. The kit's
     hooks carry the kit's policy (Conventional types, 72-character
     subjects, task ids, em dash and AI-trailer bans, prose checks, no
     push from main); each rule is a new refusal for this team. Run the
     commit-msg hook on every subject in the history (up to the last 100)
     and get zero rejections by following the team's format, not the
     kit's; drop pre-push rules the practice breaks (push from main,
     task-id branch names, terminal confirmation, refusing a push of zero
     new commits such as a tag). A pre-commit hook must let a reword
     (`--amend` with nothing staged) and an `--allow-empty` commit through.
     Cut branches for stacks the repository does not have. Any refusal
     that stays is named in the report as a change the team must agree to.
   - The documented setup path must produce the state you verified: no
     README or AGENTS.md line telling people to run a target that sets
     `core.hooksPath` in a repository whose hooks live in `.git/hooks`.
   - A hook that is written but not reachable through the hook path is
     reported as not active, with the one command that activates it.
6. **The rest of scope.** CODEOWNERS only where the host reads it first and
   only with real handles (the team's existing file, or `--lead`/`--group`
   from the engineer); a placeholder owner blocks every approval, so no
   handles means no file and a line under Not done. `.claude/settings.json`
   only when not ignored (narrow the ignore to `.claude/settings.local.json`
   when the team wants shared settings) and with the repository's package
   manager. `.gitignore`: append, never reorder or drop lines. Never create
   `.claude/settings.local.json`; add no dependency.
7. **Prove it.** Run `make check` for real with the dirty tree present and
   compare its counts with step 1's direct runs; run it once with CI's
   variables absent from your shell to show the Makefile sets them. Dry-run
   each hook (commit-msg on the history's subjects, pre-commit on a staged
   scratch file, then unstage). A hook run by hand is not a commit through
   git: say which you did. `git diff --stat` against the survey:
   every team file you changed is a deliberate, reported change.
8. **Report** (Output contract). Leave the commit to the engineer: print
   the list of files to add and a commit command in the team's format.

## Output contract

```
## Onboard: <repo> (<stack> in <dir>, ... | no stack template)
Survey: CI jobs <n> (offline <o>, need a service <s>); hooks via <mechanism>; commits <format>; owners <file>; tree <clean | dirty: files>
Gate: make check = <jobs> -> <counts>, passed | failed (<why>); not in check: <job> (CI runs it)
Hooks: <each new hook: active via <path> | not active (activate: <command>)>
Changed: <file: what and why>, one line each
Verified: <command -> result>, one line each
Not run: <what you did not exercise: a real commit or push through git, CI itself, jobs needing a service or secret, tools not installed here>
Not done: <item, with the command or decision needed>
Noticed: <doc claims found false, tracked secrets (path only: rotate, untrack), latent traps>
Commit: <git add ...> ; git commit -m "<subject in the team's format>"
```

## Gotchas

- Setting `core.hooksPath` makes git ignore `.git/hooks` completely. On a
  repository using the pre-commit framework or hand-installed hooks it turns
  them off with no message.
- `@AGENTS.md` must be a line of its own in CLAUDE.md; a markdown link
  does not import.
- The README's claim about the gate is a hypothesis. At adoption time the
  usual finding is that `make check` runs a subset of CI.
- A test that passes in CI and fails on a laptop is usually a CI variable
  (`TZ`, locale, a flag) or a working directory. Mirror it in the gate and
  report the dependence; do not edit code or tests to make it pass.
- Tracked `.env` files: report the path and recommend rotation plus
  `git rm --cached` and an ignore line. Never print a value, never rewrite
  history, never delete the local file. Nothing the run adds may load it.
- A hook source that rejects em dashes spells the pattern as
  `$'\xe2\x80\x94'`, so the hook itself passes a no-em-dash check.
- Monorepos: one Makefile at the root delegating into each service folder;
  AGENTS.md describes every service, not the primary one.
- The standard's CONTRIBUTING, SECURITY, `.editorconfig`, docs templates
  and MR templates are `--full` material. Offering them in Not done is
  fine; writing them unasked is churn the reviewer has to read.
