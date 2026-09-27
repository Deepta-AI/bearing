---
name: git-hooks
description: 'Installs or repairs the committed git hooks (commit-msg, pre-commit, pre-push), sets core.hooksPath and dry-runs each. Use when asked to "install the git hooks", "set up hooks" or "why was my commit rejected".'
argument-hint: "[--update to take the kit's copy over a differing hook]"
allowed-tools: Read, Grep, Glob, Edit, Bash(bash .githooks/install.sh:*), Bash(.githooks/commit-msg:*), Bash(.githooks/pre-commit:*), Bash(.githooks/pre-push:*), Bash(git rev-parse:*), Bash(git status:*), Bash(git diff:*), Bash(git show:*), Bash(git log:*), Bash(git ls-files:*), Bash(git cat-file:*), Bash(git check-attr:*), Bash(git clone:*), Bash(git add:*), Bash(git restore --staged:*), Bash(git hash-object:*), Bash(git update-index:*), Bash(git commit:*), Bash(gofmt:*), Bash(diff:*), Bash(mktemp:*), Bash(mkdir:*), Bash(cp:*), Bash(printf:*), Bash(make:*)
---

# git-hooks

The hooks live in the repository at `.githooks/` so every clone gets the
same ones; `core.hooksPath` makes git use them. This skill carries its own
copy (`templates/.githooks/`: `commit-msg`, `pre-commit`, `pre-push`,
`lib.sh`, `install.sh`), the same files `new-repo` and `onboard-repo`
install. Two jobs: installing hooks, and explaining a rejected commit.

Hooks are advice that `--no-verify` skips. Their worth is in rejecting
exactly what the team's rules reject, fast enough that nobody reaches for
the bypass, with CI running the same checks as the real enforcement.

## Inputs

- repository: `git rev-parse --show-toplevel`; not a git repository stops
  with "run `git init` and rerun; hooks need a repository".
- the hooks git runs today: `git rev-parse --git-path hooks` prints the
  effective directory (it honours `core.hooksPath`, including a global
  one). A directory that does not exist means no hook runs at all.
- the team's rules: CONTRIBUTING, README setup section, ADRs about hooks
  or tooling, the Makefile (`setup`, `check`, `fix`), CI config. When two
  documents disagree, an Accepted ADR beats a superseded one, and the
  hook that git enforces beats a prose example; say which one wins.
- legacy mechanisms: `.husky/`, `.pre-commit-config.yaml`, `lefthook.yml`,
  scripts that copy into `.git/hooks`, non-sample files in `.git/hooks`.
- scratch: a temporary directory outside the working tree (`mktemp -d`,
  or the scratch folder the session names). Nothing this skill creates
  for its own testing lands in the user's repository, and no `.gitignore`
  line is added to hide it.
- who commits from where: Windows clones (Git for Windows,
  `core.autocrlf=true`, `core.fileMode=false`), IDE or GUI clients, a
  terminal. It decides line endings, the executable bit and push
  confirmation below.

## Steps

### Installing hooks

1. Read the rules and the current state (Inputs) before writing
   anything. Note, with evidence, whether any hook runs in this clone
   today and whether the documented setup step would change that.
2. Place the hooks. If `.githooks/` is missing, `cp -R` this skill's
   `templates/.githooks/`. If present, `diff` each file against the
   skill's copy and report; replace only with `--update` or the
   engineer's yes.
3. Set the policy block at the top of `.githooks/lib.sh` from the
   repository's own rules, one variable per stated rule: commit types,
   branch prefixes, protected branches, file size limit (`1 MB` is 1024
   KiB), body width, gate command. A repository on the kit standard
   keeps the defaults. Elsewhere, a kit rule the repository does not
   state (em dash, AI trailer, body width, typed push confirmation) is
   off unless the team adopts it; list what you turned off. Choose
   `PUSH_CONFIRM`: `tty` only where the team pushes from a terminal and
   wants the typed confirmation; `agents` wherever people push from an
   IDE or GUI client, which has no terminal.
   Some kit rules sit in the logic, not the policy block. Check each
   against the repository and change the line when the team's rules or
   files contradict it, naming every such edit in the report:
   - the subject summary cap (`.{1,72}` in `COMMIT_RE` in `lib.sh`);
   - the refusal of root `NOTES.md`, `SUMMARY.md`, `TODO.md` in
     `pre-commit` (a repository that tracks one of them must still be
     able to commit it);
   - the branch shape `BRANCH_RE`: `<prefix>/<TICKET>-<Name>` or
     `release/vX.Y.Z`; a documented release or spike name of another
     shape needs the pattern widened, or pre-push refuses that branch;
   - the secret patterns and the size limit, against committed fixtures
     (`git ls-files` plus `git cat-file -s` finds tracked files the hook
     would refuse if they were edited).
   Keep the rest of the logic as the kit ships it so a later diff stays
   readable.
4. Make the files survive every clone. Hooks are shell scripts: a
   Windows checkout with `core.autocrlf=true` rewrites them to CRLF and
   bash then fails on `$'\r'`, so add `.githooks/* text eol=lf` to
   `.gitattributes` (check with `git check-attr eol -- .githooks/pre-commit`).
   Stage them with `git add --chmod=+x .githooks/commit-msg
   .githooks/pre-commit .githooks/pre-push` so the executable bit is
   recorded in the index; a clone on a `core.fileMode=false` system
   otherwise checks out hooks git silently skips. Staging is not
   committing; say that the engineer commits.
5. Wire one setup path: `make setup` (or the documented command) runs
   `bash .githooks/install.sh`. Retire the old installers (a script that
   copies into `.git/hooks`, a whole-suite pre-commit that contradicts a
   staged-only rule) and make README describe what setup now does.
   Add no hook framework the repository's decisions rule out.
6. `bash .githooks/install.sh`. It names the previous `core.hooksPath`
   and replaces it when its directory is missing or holds no hooks; a
   value pointing at live hooks is left and reported (chain them, or
   `--force` with the engineer's yes). It prints the hook count (3).
7. Prove every hook on inputs that must fail and inputs that must pass,
   in a throwaway clone outside the repository (`d=$(mktemp -d); git
   clone -q . "$d/c"`, then `cp -R` the uncommitted `.githooks/`,
   `.gitattributes` and Makefile into it and install there) so the
   user's repository gets no commits and no debris. Show the output.
   - commit-msg: `bad message` fails; a valid subject on a ticket branch
     passes; the same subject without the ticket fails; git's own
     `Merge branch ...` and `Revert "..."` subjects pass; anything the
     repository's rules allow (every listed type, a long unwrapped body
     line if nothing limits it, a subject longer than 72 characters if
     nothing limits it) passes.
   - pre-commit: nothing staged fails with `0 staged files, nothing
     checked`; each forbidden file kind fails (`.env`, key files, a file
     over the size limit); an existing tracked sample under the limit
     passes; a Go file staged unformatted and then fixed only in the
     working tree still fails (the hook reads the staged blob); every
     file kind the repository tracks and edits (a root `TODO.md`, a
     tracked fixture) passes when staged.
   - pre-push: feed ref lines on stdin exactly as git does,
     `<local ref> <local sha> <remote ref> <remote sha>`:
     `refs/heads/feature/X <sha> refs/heads/main <zeros>` from a feature
     branch (that is `git push origin HEAD:main`) must fail; a valid
     branch with a passing gate must pass with no terminal attached
     (under `PUSH_CONFIRM=agents`, unset the agent variable the hook
     names, such as `CLAUDECODE`, for that run); a commit made with
     `--no-verify` and a bad subject must fail; a failing gate must fail.
     Never run a real `git push`; say the hook was run directly.
8. Report: the rules each hook enforces and where each came from, the
   kit rules turned off, what the setup step now does, that every other
   existing clone must run it once (`core.hooksPath` is per clone), how
   each hook was exercised, and the CI line that makes the checks binding
   (`make check` on every merge request, and the subject check over the
   merge request's commits).

### Why was my commit rejected

1. Reproduce every rejection at once, without committing: `git status`
   and `git diff --cached --stat` for what is staged, then run
   `.githooks/pre-commit` and `.githooks/commit-msg <file with the
   intended message>`. A hook stops at its first failure, so fix and rerun
   until both pass; list each cause.
2. Judge each rejection against the repository's rules. Usually the hook
   is right and the fix is to the staged files or the message; say so
   plainly. When a document contradicts the hook (a CONTRIBUTING example
   the hook rejects), tell the user which one git enforces and fix the
   document in a separate change. Never `git commit --no-verify`, never edit a hook
   or `core.hooksPath` to get a commit through.
3. Fix only what the user staged:
   - a file that must not be committed (`.env`, a key): `git restore
     --staged <file>`; never delete or read it. Say how it got staged
     when the user's command shows it (`git add -A`, `git commit -a`), so
     they stop repeating it. If `.gitignore` does not
     cover it, add the line as a separate uncommitted change.
   - a format failure: format the file the hook named, not the whole
     repository (`make fix` drags unrelated files in). If the file also
     has unstaged edits (`git diff <file>` is not empty), `git add <f>`
     would commit them: format the index copy directly and leave the
     working file alone except for formatting:
     `t=$(mktemp) && git show :<f> | gofmt > "$t" && git update-index --cacheinfo "$(git ls-files -s <f> | cut -d' ' -f1),$(git hash-object -w "$t"),<f>" && gofmt -w <f>`.
     Then `git diff <f>` must show exactly the user's unstaged edits and
     `git diff --cached <f>` only their staged change plus formatting.
   - the message: keep the user's meaning; add the ticket the branch
     requires in the form the hook enforces.
4. Commit with the hooks running; `git show --stat HEAD` must list only
   the intended files. Run the gate (`make check`) at the new commit.
   After it, `git diff --cached` is empty and `git status` shows only
   what the user had before (their unstaged edits, the unstaged secret
   file) plus any change you propose and name.
5. Read the change you committed for the user as a reviewer would, and
   name any correctness risk you see (an edge case the new tests do not
   cover) without altering their logic in the commit.
6. Report each rejection, its cause, whether the hook was right, what you
   changed, and what you left in the working tree.

## Output contract

Installing:
```
## Git hooks: .githooks/ (copied | present, N differences)
Before: hooks ran from <dir> | none ran (<dir> missing)   Now: core.hooksPath=.githooks, 3 hooks
Rules (source): <rule> (<document>) ...   Kit rules turned off: <list or none>
Proved: <hook>: <failing input> rejected, <passing input> accepted ...   pre-push: run directly, no real push
Every other clone: run <setup step> once.   CI: <line that makes the checks binding>
```
Rejected commit: each rejection with its cause and whether the hook was
right, the commit made (subject, files), what stayed in the working tree,
and any risk seen in the change.

## Gotchas

- pre-push judges the remote refs on stdin. A hook that reads
  `git branch --show-current` lets `git push origin HEAD:main` through.
- pre-push re-checks the message of every commit it sends, since
  commit-msg is skipped by `--no-verify`. Commits already on a protected
  branch are not held against a new branch.
- The gate in pre-push runs on the checkout, not on the pushed commit;
  the hook says so when HEAD is not the pushed ref or tracked files are
  modified.
- A hook that runs the test suite on every commit gets bypassed; keep
  pre-commit to the staged files and seconds, and the suite in pre-push
  and CI.
- GUI clients run hooks with a short PATH; a missing formatter is
  printed, not silently passed.
- The pre-commit hook formats nothing; it checks. `make fix` formats.
- A hook checked out with CRLF endings or without its executable bit
  does not run, and git says nothing about a non-executable hook
  (`advice.ignoredHook` only on some versions). Line endings come from
  `.gitattributes`, the bit from the index mode, not from the file on
  the author's disk.
- The `--allow-empty` and `--amend` exemptions are read from the git
  process that ran the hook; spell the flag out (`--allow-e` fails).
- No hook file contains an em dash character; the hooks build it from
  bytes (`EM_DASH` in `lib.sh`).
- The skill's copy and `${CLAUDE_PLUGIN_ROOT}/templates/repo/.githooks/`
  are the same files; a difference between them is a kit bug to report,
  not something to resolve in the user's repository.
