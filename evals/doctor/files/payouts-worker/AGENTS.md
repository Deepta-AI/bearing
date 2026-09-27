# AGENTS.md

The standard every AI coding agent follows in this repository. It loads into
every session, so it holds only what applies on every turn.

## Ground rules

1. Never commit to `main`. Work on a task branch.
2. Never push, open a merge request, merge, tag or deploy. Prepare the
   command and hand it to the engineer.
3. Never commit a secret or `.env` file.
4. Never weaken a guardrail to go green.
5. Report honestly: a check you did not run is "not run", never "passing".

## Working here

- Every change has a task id and a branch:
  `feature|bugfix|chore|docs/<ID>-<PascalName>`.
- Every command is a Makefile target; `make help` lists them and `make check`
  is the gate CI runs.
- The committed git hooks live in `.githooks/` (commit-msg, pre-commit,
  pre-push); `make setup` points git at them once per clone. pre-push
  refuses pushes to `main` and runs `make check` before anything leaves the
  machine.
- State that must outlive the session: `.bearing/state/` (local, ignored).
  Scratch: `.scratch/`.
- Code, database, testing and security rules live in `.claude/rules/` and
  load with the files they cover.

## Reporting

End every task with Changed, Verified, Not done, Noticed.
