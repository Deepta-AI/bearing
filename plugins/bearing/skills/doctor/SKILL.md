---
name: doctor
description: 'Checks this machine and repository are set up for this plugin: skill packs, hooks, CLAUDE.md import, rules, hooksPath, with a fix per miss. Use when asked to "check my setup", "is it installed" or a hook is missing.'
argument-hint: "[path to a repository, default: the current directory]"
allowed-tools: Read, Grep, Glob, Bash(bash *bin/brg-doctor*), Bash(command -v:*), Bash(claude plugin list:*), Bash(claude --version:*), Bash(git config:*), Bash(git rev-parse:*), Bash(git ls-files:*), Bash(git check-ignore:*), Bash(git hook run:*), Bash(git status:*), Bash(git log:*), Bash(git branch:*), Bash(git remote:*), Bash(git clone:*), Bash(stat:*), Bash(ls:*), Bash(make -n:*), Bash(make check:*), Bash(node --test:*), Bash(node --check:*), Bash(python3 -m pytest:*), Bash(go test:*)
---

# doctor

Runs `bin/brg-doctor` from the plugin, then proves or refutes each line that
matters against the repository, and gives the exact fix for every real miss.
The script is a fast first pass: most of its checks ask whether a thing
exists. The job is whether it works.

## Inputs

- The doctor script: `${CLAUDE_PLUGIN_ROOT}/bin/brg-doctor`; if the variable
  is unset, the Bearing path from `claude plugin list`; else
  `~/.claude/plugins/*/bearing*/bin/brg-doctor` by glob. None: the plugin is
  not installed, which is the first finding; run the machine checks inline
  (`command -v claude git make jq`, `claude plugin list` for superpowers,
  `~/.claude/skills/gstack/VERSION`, `~/.claude/CLAUDE.md`).
- Repository: `git rev-parse --show-toplevel`; none means machine checks
  only, and the report says so rather than giving a clean bill.
- Profile: `BEARING_PROFILE` (environment, then `~/.config/bearing/bearing.env`).
  `standard` or `full` makes Superpowers and gstack required; unset or
  `minimal` makes them `optional`.
- The user's complaint, if there is one ("nothing stopped my push"): every
  finding is judged by whether it explains that.

## Steps

1. Run the doctor from the repository root. Read every line: `ok`,
   `MISSING`, `optional`, and the `N checks, M missing` summary.
2. Read what the repository says its setup is (AGENTS.md, CONTRIBUTING,
   README, the Makefile `setup` and `check` recipes, the CI file, each hook
   and anything that chains to it). The repository's own statement is the
   spec; the doctor's list is not complete.
3. Verify the parts that decide the answer. Work in the user's clone
   read-only; to run anything that writes (`make setup`, a test commit, a
   push to a bare remote) use a throwaway `git clone` under the scratch
   directory, never the user's clone.
   - A hook runs only when all hold: `core.hooksPath` (else `.git/hooks`)
     points at it, the name is exact, it is executable, and whatever chains
     to it passes its arguments and keeps its exit status (`|| exit $?`, not
     `|| true`). `git hook run <name> -- <args>` runs it as git would.
   - The executable bit that travels is the index mode: `git ls-files -s`
     shows `100755` or `100644`. `chmod +x` fixes one clone;
     `git update-index --chmod=+x <file>` plus a commit fixes every clone.
   - `make setup` works only if it runs: `make -n setup`, then check each
     script it names exists. A recipe line starting with `-` ignores its
     failure, so the target exits 0 and any later `echo` prints success;
     that is why people believe setup ran.
   - A gate is enforced only if CI runs it and CI runs at all: the CI file
     calls `make check` (or every target it depends on), and its triggers
     (`on: push/pull_request: branches`, `workflow: rules:`, `rules:`,
     `only:`) match the trunk the repository uses. A workflow filtered to
     `master` in a `main` repository never runs; GitLab `workflow: rules`
     limited to `merge_request_event` runs nothing for a direct push to
     trunk. A step with `|| true`, `continue-on-error`, `allow_failure` or
     `when: manual` does not gate.
   - A passing gate proves only what it examined. Compare the counts it
     prints with the repository: the files its runner discovers (`node
     --test` with no paths: `*.test.js`, `*-test.js`, `*_test.js`,
     `test-*.js`, `test.js`, `test/**`; pytest: `test_*.py`, `*_test.py`
     under `testpaths`; Go: `*_test.go`; Jest: `testMatch`) against every
     file that defines tests (`grep -rlE 'test\(|def test_|func Test'`).
     Run the undiscovered ones directly once: a test the gate never runs,
     failing, is the headline.
   - A command handed a file list (lint-staged, pre-commit's
     `pass_filenames`, `xargs`) gets every file at once; a tool that takes
     one path checks only the first (`node --check a.js b.js` ignores
     `b.js`). Probe it with a good file first and a broken one second.
   - A fix that adds files must survive `.gitignore`: `git check-ignore -v
     <path>` on each file the fix would create (`.claude/rules/*.md`, hook
     files). A `.claude/*` rule hides new rules from every other clone.
   - Read a hook's rule before calling its behaviour a fault. A commit-msg
     that takes the task id from the branch name accepts an id-less subject
     on `main` by design; the answer there is the task branch, and tightening
     the rule is a team decision to propose, not a fix to apply.
   - A pre-push that judges `git branch --show-current` instead of the refs
     on its stdin (`<local ref> <local sha> <remote ref> <remote sha>`) does
     not stop `git push origin HEAD:main` from another branch. A replacement
     refuses any line whose remote ref is `refs/heads/main`, skips a delete
     (local sha all zeros), and keeps the hook's other checks.
   - `core.hooksPath` replaces `.git/hooks` entirely: before recommending
     it, list the executable non-sample files in `.git/hooks` (git-lfs and
     other tools install there); they stop running unless chained.
   - Husky: `prepare: husky install` (v8) or `husky` (v9) rewrites
     `core.hooksPath` on every `npm install` (v9 uses `.husky/_`, whose
     wrappers run `.husky/<hook>`). Chain `.githooks/<hook> "$@" || exit $?`
     into each Husky hook; pointing `core.hooksPath` at `.githooks` drops
     Husky's own hooks and is undone on the next install. Say which.
4. Run `make check` if it is cheap and needs no service; report its tail.
   Otherwise say "not run". Never report a result you did not observe.
5. Fix nothing unless the user asked for fixes. When they did, change only
   hooks, the Makefile, CI, ignore rules or local git config; leave `src/`
   and tests alone; list every file changed and what still needs a commit.
   A committed fix reaches the team through a task branch and a merge
   request, never a commit on trunk; say which branch it belongs on.
6. Report.

## Fixes by miss

- Plugin missing: `bash <Bearing>/install.sh`, or
  `claude plugin install bearing@bearing`. A stack plugin `optional` while
  the repository uses its stack:
  `claude plugin install bearing-backend@bearing` (or `bearing-apps@bearing`).
- superpowers: `claude plugin install superpowers@claude-plugins-official`.
  gstack: `bash <Bearing>/install.sh --skip-gsd --skip-superpowers` (pinned
  in `${CLAUDE_PLUGIN_ROOT}/bin/pinned-packs.txt`). GSD:
  `npx @opengsd/gsd-core@1.14.0 --global --claude`.
- CLAUDE.md import, rules, Makefile `check`, CI or template missing:
  `onboard-repo`. Unfilled `__PLACEHOLDERS__`: give the value only when the
  repository shows it (a driver import, `.env.example`, the start script);
  otherwise say it is unknown.
- `core.hooksPath` unset: `bash .githooks/install.sh` in this clone, and say
  that every existing clone needs the same one-time step; committing a fix
  does not set anyone's config.
- User CLAUDE.md missing: copy `${CLAUDE_PLUGIN_ROOT}/templates/user/CLAUDE.md`
  to `~/.claude/CLAUDE.md`.

## Output contract

```
## Doctor: <N> checks, <M> missing, <K> optional (machine + repository <name> | machine only)
Changed: nothing | <files, and what still needs committing>
Verified: <what was proven, with the command that proved it>
Not done: <each real miss: cause, then the fix command or file edit>
Noticed: <script false alarms, extra findings, what was not checked>
```

Lead with the answer to the user's question. Every miss gets a fix a person
can type. State as fact only what a command showed: with no `git remote`,
what is on the server, CI results and branch protection are unknown, and
anything the user reported stays "you said". Name what was not checked on
the machine (installed packs, `~/.claude/CLAUDE.md`) when the run could not
see it.

## Gotchas

- Local hooks are advisory: `--no-verify`, a clone that never ran setup, or
  a web edit skips them. Only protected-branch settings on the Git server
  reliably refuse a push to `main`; say so whenever the complaint is a push.
- A doctor `ok` can be wrong and a `MISSING` can be a false alarm; confirm
  both before reporting, and say which the script got wrong.
- Never rewrite history, reset, revert or push to undo the user's commit;
  describe the options and leave them to the user.
- Optional packs (GSD always; Superpowers and gstack below `standard`) are
  notes, not failures.
- Inside the Bearing checkout the repository section is skipped by design.
