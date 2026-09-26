---
name: explain-codebase
description: 'Explains a repository or subsystem read-only, path:line for every claim: entry points, module map, one request traced, key files. Use when asked to "explain this repo", "how does this work" or "where is X handled".'
argument-hint: "[question, subsystem or path; default the whole repo]"
context: fork
agent: explorer
allowed-tools: Read, Grep, Glob
---

# explain-codebase

A map with coordinates. Every sentence names a file and a line so the
reader can check it in one keystroke instead of trusting it.

Not this: `workflow` says which skill comes next; `branch-review` judges
a diff. This one only describes what is there and never writes.

## Inputs

- Question: `$ARGUMENTS`, a question, a subsystem name or a path; if
  absent, "the whole repo".
- Entry points: `Makefile` targets, `package.json` scripts, `go.mod` plus
  `cmd/*/main.go` or `main.go`, `pyproject.toml` `[project.scripts]`,
  `Dockerfile` `CMD` and `ENTRYPOINT`, `Procfile`, `compose.yaml`
  `command:`; none found: grep for `func main`, `if __name__`,
  `createRoot`, `app.listen`, `uvicorn` and mark them "inferred".
- Claimed conventions: `CLAUDE.md`, `AGENTS.md`, `CONTRIBUTING.md`,
  `README.md`, `docs/`; if absent, the claimed column reads "no docs" and
  only the observed column is filled.
- One request or job to trace: named in the question; for the whole
  repo, the first route or command reached from the first entry point.
- Nothing else. No build, no test run, no write.

## Steps

1. Inventory: top-level directories and source files per language
   (Glob), excluding `node_modules`, `vendor`, `dist`, `build`,
   `.venv`, generated files (`*.pb.go`, `*.gen.ts`, `*_generated.*`).
   Print "N directories, M source files" first. M=0: stop with "0
   source files under <path>; nothing to explain".
2. Entry points from Inputs, one `path:line` each. A monorepo lists one
   row per package.
3. Module graph: for each top-level source directory, what it imports
   and what imports it (grep the import lines). An indented list of at
   most 12 nodes; the rest collapse to "+N leaf packages".
4. Trace one request or job end to end: entry, routing, handler,
   service, store, response or side effect, each `path:line`. A job
   traces from its trigger (cron, consumer, timer) to its effect, and
   says what it does when the effect fails. Then grep for every caller
   of the write the trace ends in: another entry that reaches the same
   write is one more trace line naming the checks it skips.
5. The ten files that matter: those on the trace plus the most imported
   (grep import counts), ranked, at most ten, five words each.
6. Conventions, observed versus claimed: test file naming, error
   handling shape, logging call, config loading, migration tool,
   formatter (from hooks or CI). Print "K conventions checked" and mark
   each `match`, `drift` (both paths) or `unclaimed`. K=0 cannot
   happen once M>0: at least test naming and error shape are observable.
7. Where to change X: when the question names a change, the files to
   touch in order with the test file beside each; otherwise "not asked".
8. Risks: behaviour read on the trace that loses data, repeats a side
   effect or contradicts the docs, each `path:line`, marked "read, not
   run". Unconfirmed items last: only what the code cannot settle
   (callers outside the repo, production data). Under 60 lines total.

## Output contract

```
## Explain: <question | the whole repo> (N directories, M source files)
Entry points: <path:line> <five words>; ...
Module graph:
  <dir> -> <dir>, <dir>
Trace (<request or job>): <path:line> -> <path:line> -> ...
Ten files: <path:line> <five words> (x10 or fewer)
Conventions: K checked, match A, drift B, unclaimed C
  <convention>: observed <path:line> | claimed <doc:line> | match|drift|unclaimed
Change X: <path> (test: <path>); ... | not asked
Risks (read, not run): <path:line> <what goes wrong>; ... | none
Unconfirmed: <item>; ... | none
```

## Gotchas

- A line without a `path:line` is an opinion. Cut it or find the line.
- Docs describe the repository someone meant to build; grep describes
  the one that exists. Report the drift, do not pick a side.
- The most imported file is a `utils` file in every repository. Rank by
  the trace first, import count second.
- Two entry points that look alike (a CLI and a server sharing `main`)
  are one row with two lines, not a guess at which is primary.
- Sixty lines is the ceiling, not a target. A small repository gets a
  short map.
