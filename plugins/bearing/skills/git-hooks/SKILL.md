---
name: git-hooks
description: 'Installs or repairs the committed git hooks (commit-msg, pre-commit, pre-push), sets core.hooksPath and dry-runs each. Use when asked to "install the git hooks", "set up hooks" or "why was my commit rejected".'
argument-hint: "[--update to take the kit's copy over a differing hook]"
allowed-tools: Read, Grep, Glob, Bash(bash .githooks/install.sh), Bash(.githooks/commit-msg:*), Bash(.githooks/pre-commit:*), Bash(git rev-parse:*), Bash(diff:*), Bash(mkdir:*), Bash(cp:*), Bash(printf:*), Bash(make -n:*)
---

# git-hooks

The hooks live in the repository at `.githooks/` so every clone gets the
same ones. `core.hooksPath` makes git use them. This skill carries its
own copy of the hooks, so it works in a repository that has never seen
the kit.

## Inputs

- repository: `git rev-parse --show-toplevel`; not a git repository
  stops with "run `git init` and rerun; hooks need a repository".
- hooks: the repository's `.githooks/` when present; if absent, this
  skill's own `templates/.githooks/` (`commit-msg`, `pre-commit`,
  `pre-push`, `lib.sh`, `install.sh`), the same files `new-repo`
  and `onboard-repo` install.
- gate for pre-push: a Makefile `check` target; if absent, the hook
  itself skips the gate with a note, and the report says the gate is
  missing (`new-repo` or `onboard-repo` install the Makefile).
- scratch directory: `.scratch/`; created with `mkdir -p`; if
  `.gitignore` exists and lacks the line, say so.
- task id for the dry run: the branch name; on a branch without one the
  test message carries `[TASK-1]` and passes.

## Steps

1. If `.githooks/` is missing, `cp -R` this skill's `templates/.githooks/`
   into the repository. If present, diff each file against the skill's
   copy and report differences; update only with `--update` or the
   engineer's yes.
2. `bash .githooks/install.sh`. It sets `core.hooksPath`, marks the hooks
   executable, and prints the hook count (must be 3).
3. Prove each hook with a dry run and show the output:
   - commit-msg: `printf 'bad message\n' > .scratch/m && .githooks/commit-msg .scratch/m` must fail;
     `printf 'feat(x): add y [TASK-1]\n' > .scratch/m && .githooks/commit-msg .scratch/m` must pass
     (on a branch without a task id).
   - pre-commit: `.githooks/pre-commit` with nothing staged must fail
     with `0 staged files, nothing checked`; a gate that examined
     nothing did not pass. The hook passes on zero files only when git
     itself treats the commit as real, and names the reason: a
     deletion-only commit, a merge whose tree equals HEAD, or a commit
     run with `--allow-empty` or a reword with `--amend`.
   - pre-push: `make -n check` must resolve; without a Makefile the hook
     prints `no Makefile; skipping the gate` and that line is the
     evidence.
4. Explain the three rules the hooks enforce in three lines, and how to
   bypass for a genuine emergency (`git commit --no-verify`, which the
   pre-push will still catch on the branch name and gate).

## Output contract

```
## Git hooks: .githooks/ (copied | present, N differences)
core.hooksPath: .githooks   Hooks installed: 3 (commit-msg, pre-commit, pre-push)
Dry run: commit-msg rejects "bad message": yes; accepts "feat(x): add y [TASK-1]": yes
         pre-commit refuses 0 staged files: yes; pre-push: make -n check resolves | no Makefile, gate skipped
Rules: Conventional subject with [ID] on a task branch; staged-file checks; branch name and gate before push
```

## Gotchas

- `core.hooksPath` is per clone. `make setup` calls `install.sh` so a new
  clone gets it; without a Makefile, say the command to run per clone.
- The pre-commit hook formats nothing; it checks. `make fix` formats.
- The `--allow-empty` and `--amend` exemptions are read from the git
  process that ran the hook (`ps -o args=`). An abbreviated flag such
  as `--allow-e` is not recognised and fails; spell the flag out.
- A commit rejected for a missing `[TASK-ID]` on a task branch is correct
  behaviour; the fix is the message, not the hook.
- The skill's copy and `${CLAUDE_PLUGIN_ROOT}/templates/repo/.githooks/`
  are the same files; a difference between them is a kit bug to report,
  not something to resolve in the user's repository.
