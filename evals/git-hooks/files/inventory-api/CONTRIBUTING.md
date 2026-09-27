# Contributing

## Branches

Work happens on a short-lived branch named after the ticket:

- `feature/INV-123-ShortName` for features
- `bugfix/INV-123-ShortName` for fixes
- `spike/INV-123-ShortName` for throwaway experiments (never merged)
- `release/v1.4.0` for releases

Nobody commits or pushes to `main` directly; changes arrive through a merge
request.

## Commits

- Subject in Conventional Commits form: `type(scope): summary`, where type is
  one of feat, fix, refactor, style, test, docs, chore, perf, build, ci.
- On a ticket branch the subject ends with the ticket id in brackets:
  `fix(stock): stop negative reservations [INV-88]`.
- Merge and revert commits keep the subject git writes for them.
- The body is free-form. When a fix answers a failing CI job or an alert,
  paste the log line or the job URL as it is, unwrapped, so it can be
  searched for later.

## What never goes into the repository

- `.env` files, private keys (`*.pem`, `*.key`) or any credential.
- Any file over 1 MB. Large receipt dumps live in the shared bucket; see
  `testdata/README.md`. (INV-61: a 38 MB dump went in last quarter and every
  clone still downloads it.)

## Before you push

`make check` must pass. CI runs the same target on every merge request.

Most of the team commits and pushes from the GoLand or VS Code Git panel,
not a terminal, so anything that runs on commit or push has to work there
too. Four of us are on Windows laptops with Git for Windows installed with
its default settings.

## Deferred work

When you leave something for later, add a line to `TODO.md` at the root
with the ticket id, in the same merge request.
