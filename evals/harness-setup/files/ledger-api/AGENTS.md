# AGENTS.md

The engineering standard for every coding agent working in ledger-api.

## Ground rules

- Never push, merge, tag or deploy. A person does that. Prepare the command
  and print it instead.
- `make check` passes before you say a change is done. Say what you did not
  run.
- Work on a feature branch named `feature/LEDG-<n>-<slug>`; never commit to
  main.
- Ask one question when the request is ambiguous; otherwise state your
  assumption and proceed.

## Code

- Go 1.25, standard library first. Money is always an int64 in minor units,
  never a float.
- Table-driven tests next to the code (`*_test.go`).
- Errors are wrapped with context (`fmt.Errorf("...: %w", err)`).

## Database

- Migrations live in `db/migrations/` and run with goose.
- A migration that has been applied anywhere is never edited. Add a new
  migration instead.

## Git

- Commits follow Conventional Commits.
- The git hooks in `.githooks/` check commit shape and formatting, and
  refuse a push unless a person types the branch name on the terminal.
  Run `make hooks` once after cloning to enable them.

## Report

End every task with: Changed, Verified, Not done, Noticed.
