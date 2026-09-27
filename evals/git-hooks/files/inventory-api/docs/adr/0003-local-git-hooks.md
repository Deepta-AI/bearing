# ADR-0003: Local git hooks without a framework

Status: Accepted
Date: 2026-03-18

## Context

The dashboard moved to its own repository in March 2026 and took package.json
and `.husky/` with it (ADR-0001 is superseded). This is now a Go-only
repository, and nobody should need Node or Python tooling to get the hooks.

The old pre-commit hook ran the whole gate (gofmt, vet and every test) on
every commit. It takes about a minute and people bypass it with
`--no-verify`, which defeats it.

## Decision

- Hooks are plain shell scripts committed in this repository, with no hook
  framework to install (no Husky, no pre-commit.com).
- pre-commit checks only the staged files and must finish in a few seconds.
  It never runs the test suite.
- The full gate, `make check`, runs before a push and in CI.

## Consequences

A fresh clone has to point git at the committed hooks once; `make setup` is
the documented way.
