---
name: session-handoff
description: 'Saves session state for the next session on this branch: next steps, done, blockers, questions, files, gate, and a progress note. Use when asked to "save state", "write a handoff", "pause here" or before /clear.'
argument-hint: "[note to put first under Next]"
allowed-tools: Read, Write, Grep, Glob, Bash(git status:*), Bash(git diff:*), Bash(git branch:*), Bash(git log:*), Bash(git rev-parse:*), Bash(git rev-list:*), Bash(git stash list:*), Bash(git stash show:*), Bash(git show:*), Bash(git for-each-ref:*), Bash(git merge-base:*), Bash(git ls-files:*), Bash(git check-ignore:*), Bash(make check:*), Bash(make -n:*), Bash(date:*), Bash(mkdir -p .bearing/state), Bash(mkdir -p docs/handoff), Bash(bash *bin/brg-state-path*), Bash(python3 *skills/session-handoff/scripts/progress.py*)
---

# session-handoff

A handoff fails in two ways: it loses work (a commit, a stash or a branch
that lives only on this machine), or it passes on a wrong belief (a
"(done)" commit whose test is skipped, a gate result nobody ran, a decision
someone else has already taken upstream). The next reader trusts the note
and cannot ask you, so every line must be checked against the repository,
not remembered from the session.

## Who reads it decides where it goes

- **You, after /clear or tomorrow, on this machine**: the local state file
  `.bearing/state/<branch with / as _>.md` (`bash
  "${CLAUDE_PLUGIN_ROOT}/bin/brg-state-path"` prints it). It is git-ignored;
  the SessionStart hook prints its first twenty lines back, so the top
  carries the most useful facts.
- **Someone else, or another machine** ("someone is picking this up", "I'm
  out", "hand over"): the ignored file never leaves this machine, so the
  full handoff goes in a tracked file, `docs/handoff/<ID>.md`, with the same
  body. Everything the teammate needs is in that file: criteria status,
  traps, blockers, how to run the checks, what is still only on your
  machine. Never leave an essential fact only in the ignored file or only in
  your final message.
- Either way, update the shared summary `docs/progress/<ID>.md` with
  `scripts/progress.py` (format in `templates/progress.md`); it is committed
  on the task branch and each branch writes only its own, so they never
  conflict.

Not this: `client-handover` is the client pack at the end of an
engagement; `task-report` says what a task did. This says where work
stopped and what to do first.

## Inputs

- The repository and branch (`git rev-parse --show-toplevel`, `git branch
  --show-current`); outside a git repository, write the local file anyway
  and say so in it.
- Task id: from the branch name (`[A-Z][A-Z0-9]*(-[0-9]+)+`); else the
  existing state file's title; else the branch name with `/` as `_`.
- The ticket and its acceptance criteria (`docs/tasks/<ID>.md` or where
  the repository keeps them), and the reader (from the request).
- `$ARGUMENTS`, when given, is the first line under Next.

## Steps

1. **Locate the base.** The base is the branch the task was cut from, read
   from CONTRIBUTING, README or the existing file's `Base:` line; do not
   guess `main`. Count with `git rev-list --count <base>..HEAD` and list
   with `git log --oneline <base>..HEAD`: commits reachable from the wrong
   base belong to other tasks, and crediting them is a false "done".

2. **Find everything that is only on this machine.** Each of these is
   invisible to a teammate and lost with the laptop:
   - `git status --porcelain=v2 --branch`: modified, staged, untracked
     (say which files are untracked; they are not in any commit).
   - Ahead and behind upstream: `git rev-list --left-right --count
     @{u}...HEAD`. Ahead: those commits must be pushed. No upstream: the
     whole branch is local.
   - **Behind upstream: read what came in** (`git log -p HEAD..@{u}`).
     Someone else may have changed a document you are about to describe
     (an ADR accepted, a ticket edited, a test changed). Report the
     upstream version and the conflict with your working tree; do not
     describe the local copy as current.
   - `git stash list` and `git stash show --stat --include-untracked
     stash@{n}` for each: what it holds and which criterion it serves.
   - Local branches with no upstream or with unpushed commits: `git
     for-each-ref --format='%(refname:short) %(upstream:short)
     %(upstream:track)' refs/heads` and `git log --oneline --branches
     --not --remotes`. A side branch with a helper or a spike is easy to
     forget.
   For each item say what it is and what the user should do before
   leaving (commit, push, turn the stash into a branch). Print the
   commands; do not run them. You do not commit, push, pop, drop or apply
   anything.

3. **Run the checks; do not trust a marker.** Run the repository's gate
   (`make check`, or what README or CONTRIBUTING names) once, when it runs
   locally in a minute or two, and record the exact counts: passed,
   failed, skipped, and the names of the failing and skipped tests. A
   `.bearing/state/.check-passed` marker or a remembered run is at best
   "last known"; say so with its time. If the gate cannot run here (needs a
   service, a secret, the network), say "not run" and why. A green run with
   skipped tests is green only for what ran.

4. **Status each acceptance criterion from evidence.** Read the ticket's
   criteria. For each, name the code and the test that proves it and say
   done, partly done, not started or blocked. Claims are not evidence: a
   commit message saying "(done)", a ticked box or a comment is a claim.
   A skipped or xfailed test proves nothing, and "flaky" in a skip reason
   often hides a real bug: read the code path it covers (or run it
   unskipped in a scratch copy, never in the repository) and say whether
   the behaviour works. Read what a test
   asserts before counting it: a test that pins the value the ticket calls
   the bug documents the bug, it does not meet the criterion. When a number
   decides a status (a total, a rounding, a timeout), compute it.

5. **Look for secrets in the working tree**, not only in the conversation:
   `git diff` and every untracked file, for literal keys, tokens and
   passwords (a `TEMP` or `debug` comment beside a credential is the usual
   shape). Record the file and variable, never the value or any part of it.
   The first Next step becomes "revert it before any commit"; do not edit
   the file yourself unless asked.

6. **Write the handoff** (the local file, and `docs/handoff/<ID>.md` when
   the reader is someone else). Under sixty lines, facts not narrative:

   ```
   # <ID> <title from the ticket>
   Updated: <date time>   Branch: <branch>   Base: <base>
   Gate: <command> <counts, failing and skipped names> | not run: <why>
   Only on this machine: <unpushed commits, stash, local branches, untracked files, or none>
   ## Next (do this first)
   - one to three concrete actions naming a file, test or function;
     a safety step (revert a key, push the branch) comes first, then the
     first real task step
   ## Criteria
   - <n> <done | partly | not started | blocked>: <evidence>
   ## Done
   - commits on this branch since the base, by hash and subject
   ## Blockers
   - what stops progress, who or what can unblock it, as the repo states it
   ## Open questions
   - decisions still owned by someone else; Proposed stays Proposed
   ## Traps
   - what the next reader would otherwise get wrong: a claim the code
     does not back, a skipped test, an ordering hazard in code still to
     be wired, a change waiting upstream
   ## How to run
   - the gate command and the documents to read first
   ```

   Invent nothing: no names that are not in the repository or the request,
   no reply that has not arrived, no decision nobody took, no dates beyond
   today's and arithmetic on dates the user gave (say it is derived). A
   recommendation is labelled as yours and Proposed.

7. **Update the progress file**: `python3
   "${CLAUDE_PLUGIN_ROOT}/skills/session-handoff/scripts/progress.py" write
   --task <ID> --status <in progress | blocked | in review> --next <first
   Next action> --add-done <item> (once per new commit) --blocker <item>
   (once each, or none)`. On its first write also pass `--title` (the
   ticket title), `--criteria` (the ticket path and a one-line tally) and
   `--started` (author date of the first commit since the base); Owner
   defaults to the author of the latest commit. `blocked` only when nothing
   can move. Nothing secret, nothing from Open questions.

8. **Leave the tree as you found it**, apart from the handoff files. No
   code edits, no commits, no stash operations, no stray scratch files or
   caches in the repository (delete the ones the gate created if they are
   not ignored).

## Output contract

```
## Handoff: <path(s) written> (N lines)
Branch: <branch>   Task: <ID | none>   Base: <base> (+N commits)   Gate: <counts> | not run
Only on this machine: <items, or none>
Next:
- <first action>
Criteria: <n done, n partly, n open>   Blockers: N   Open questions: N
Before you go (run these yourself):
  <git add/commit of the handoff files, git push, stash-to-branch, as needed>
```

## Gotchas

- The state file stays ignored; never commit it. The progress file and a
  `docs/handoff/` file are shared; never add them to `.gitignore`.
- The file is per branch. Switching branches switches state; say so if the
  user is about to switch.
- A clean tree, nothing local-only and no open questions makes a one-line
  handoff: "clean, pushed, next: <action>".
- Date arithmetic: "two weeks from tomorrow" is a derived date; state the
  arithmetic, or leave it out.
