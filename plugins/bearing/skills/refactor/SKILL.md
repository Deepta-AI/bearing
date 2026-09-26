---
name: refactor
description: 'Refactors without changing behaviour: tests green first, one mechanical change per commit, checks between, a diff size ceiling. Use when asked to "refactor", "clean this up", "extract" or "rename across the codebase".'
argument-hint: "<path, symbol or module> [--max-diff 400]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(ls:*), Bash(mkdir -p:*), Bash(make check:*), Bash(make test:*), Bash(make fmt:*), Bash(make -C:*), Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git branch:*), Bash(git switch -c:*), Bash(git rev-parse:*), Bash(git show:*), Bash(git add:*), Bash(git apply:*), Bash(git restore --staged:*), Bash(git commit -m:*), Bash(git checkout -- :*), Bash(git archive:*), Bash(tar -x:*), Bash(go test:*), Bash(gopls rename:*), Bash(pnpm exec vitest:*), Bash(pnpm exec tsc:*), Bash(uv run pytest:*), Bash(python3 -c:*), Bash(./gradlew test:*), Bash(swift test:*)
---

# refactor

A refactor changes the shape of the code and nothing a test can see.
The tests are the witness: green before the first transform, green after
every transform, and each diff small enough to read in one sitting.

Not this: a change a user could notice is a feature; `start-task` starts
it. A red test with no obvious cause is `systematic-debugging`.

## Inputs

- Target: `$1`, a path, a symbol or a module; if absent, one question:
  "what should be restructured, and what must stay the same?".
- Diff ceiling: `--max-diff N`, lines added plus removed per transform;
  default 400.
- Test command: `make test` when the Makefile has it; else the stack's
  runner (`go test ./...`, `pnpm exec vitest run`, `uv run pytest`,
  `./gradlew test`, `swift test`); none found: characterisation tests
  are written first (step 2) and the report says the repo had no runner.
- Check command: `make check`; if absent, the test command doubles as
  the check and the report says "no check target".
- Existing tests for the target: grep the test folders for the symbol or
  module name; zero hits means step 2 runs before anything moves.
- Rename tooling: `gopls rename` for Go, `pnpm exec tsc --noEmit` to
  confirm TypeScript references, grep plus Edit for the rest with the
  site count printed.
- Task id: from the branch name (`[A-Z][A-Z0-9]*(-[0-9]+)+`), appended
  to every subject as `[KEY]`; no id on the branch, no suffix. No ticket
  is touched here; `BEARING_TRACKER=none` changes nothing.

## Steps

1. Baseline, the developer's work in progress, and where commits land:
   - `git status --porcelain`; a dirty tree is not a stop. Save the work
     in progress first: `git diff > <tmp>/wip.patch` outside the
     repository, and note every untracked path. Never stash it, never
     stage everything or commit with -a, never check out a file that
     carries it: stage named paths only, and in a file
     holding both the developer's hunks and yours, stage only yours
     (write your hunks to a patch, then `git apply --cached <patch>`).
     Stop and ask only when the work in progress edits the very lines a
     transform must move.
   - On the default branch, or one CONTRIBUTING or README says is
     protected or reached by merge request: cut a branch first
     (`git switch -c refactor/<target>`); the work in progress comes
     along untouched. Name the branch in the report.
   - Told to leave it uncommitted, or not to commit: no commit at all,
     not even the formatter or characterisation steps; every "commit"
     below becomes a checkpoint (tests green, diff recorded), and the
     report says how to see the whole change with new files included
     (`git status`, or `git add -N`, because `git diff` omits untracked
     files).
   - Run the formatter (`make fmt` when present) and commit any churn on
     its own. Run the test command; print "baseline: N passed, 0 failed"
     with N read from the runner's summary line. N=0 or any failure:
     stop; a refactor starts green or not at all.
2. Characterisation: when the target or anything it moves has no tests
   (grep per function, not per module), write tests that pin what it
   does now (inputs, outputs, side effects, error shapes, state callers
   set from outside) from the current behaviour, not from what it should
   do. Run them; print "characterisation: C tests, C passed". Commit
   alone: `test(<scope>): characterise <target> before refactor [KEY]`.
   New tests are the witness, not a behaviour change; step 6 does not
   fire on them.
3. Contracts: list what outside code reaches by name and must keep
   resolving: every public name the module defines (not only the ones a
   README lists), dotted paths in settings and config, logger names
   derived from `__name__`, module globals other code assigns
   (`mod.counter = ...`), exported Go identifiers, JSON keys taken from
   untagged field names, log keys and messages, metric names, error
   strings. Print the list and its count. A transform that would change
   one keeps it (re-export, alias, pinned logger name, explicit tag) or
   is dropped.
4. Plan the transforms as a numbered list, one mechanical operation
   each: rename, extract function, extract module, inline, move, replace
   conditional with polymorphism, introduce parameter object, split
   file. Print the list and its count before touching code. A step that
   is not one of these is rewritten until it is, or dropped.
5. For each transform, in order:
   - Apply it with the tool from Inputs; print "sites changed: N".
   - Run the check command, then the test command; print "tests: N
     passed, 0 failed". Any failure: undo only your own edits for that
     transform (`git apply -R <your patch>`; `git checkout -- <file>`
     only on a file with no work in progress in it), report it, stop.
   - Each new module imports on its own in a fresh process (Python:
     `python3 -c "import <pkg>.<module>"` per new module); a cycle that
     only another import order hits is caught here, not by the export
     job that loads the new path first.
   - `git diff --stat`: added plus removed over the ceiling means split
     the transform and redo it as two.
   - Commit (unless told not to), staging the transform's own paths and
     hunks, with any new module in the same commit as its importers:
     `refactor(<scope>): <transform> <target> [KEY]`.
6. Behaviour gate, checked before every commit: an existing test's
   assertion changed or was deleted, a golden file or fixture changed, a
   contract from step 3 changed (a name outside code imports, a dotted
   path, a logger name, a log line, a metric name, an error message, a
   JSON key, a string a user sees). Any one: undo the step, stop with
   "that is a feature; use start-task", and list what would change. An
   exported name a rename touches is not a stop: keep the old name as a
   deprecated alias or wrapper (Go: `type Old = New`, the same error
   value, a doc paragraph starting "Deprecated: use New."; Python: a
   re-export), pin it with a test, and name the importers it keeps
   working. Only where an alias cannot exist (a struct field, a module
   global callers assign) does the old name stay, and the report says
   why; a private name outside code used that no longer works is
   reported by name.
7. Final run of the test command; print before and after counts (after
   equals baseline plus C). When commits were made, check each one on
   its own, since the working tree also holds the work in progress:
   `mkdir -p <tmp>/<sha>`, `git archive <sha> | tar -x -C <tmp>/<sha>`,
   `make -C <tmp>/<sha> check`. Confirm `git diff` of the work in
   progress still equals the saved patch and the untracked paths are
   unchanged. Print the contract.

## Output contract

```
## Refactor: <target> (T transforms, ceiling <N> lines)
Branch: <name> (from <base>) | uncommitted, as asked
Baseline: N passed, 0 failed   Characterisation added: C tests
Contracts: N kept   Changed or removed: <names, private ones included> | none
| # | Transform | Sites | Diff (+/-) | Check | Tests | Commit |
...
After: N passed, 0 failed (baseline N + C)
Work in progress: untouched, in no commit | none found
Files touched: N   Largest diff: N lines
Stopped: <transform: reason> | none
```

## Gotchas

- Python: `logging.getLogger(__name__)` renames the logger when the
  code moves, and alert rules and log filters match on that name. Pin
  it (`getLogger("pkg.old")`) or change the rule in the same step and
  say so.
- Python: `from old import counter` copies the value; a caller that
  later assigns `old.counter = 5` no longer reaches code that moved.
  Grep for assignments to module attributes and route them to the new
  owner, and report the old name as no longer effective.
- A module that re-exports from a new module which imports back from
  it works in one import order only; a dotted path that loads the new
  module first hits the cycle. Import each new module alone.
- Go: an untagged exported struct field's name is its JSON key;
  renaming the field changes every file and response that encodes it.
- "While I am in here" is how behaviour changes ride along. The stop in
  step 6 fires even when the change is an improvement; a pinned bug
  or a document that contradicts the code is reported, not fixed.
- A rename that grep finds inside strings (log messages, config keys,
  JSON fields, column names) is not mechanical any more; those are
  contracts. List them, rename only the symbol.
- Extracting a function changes evaluation order when arguments have
  side effects. Read the call sites before extracting, not after the
  tests go red.
- A characterisation test that pins a bug is correct; it pins the
  present. The bug is a separate task after the refactor.
- A test that passes only by ordering or shared state fails mid-sequence
  and looks like the transform's fault. The revert keeps the sequence
  honest; the flaky test goes to `test-heal`.
- Formatting churn hides the transform; that is why the formatter runs
  before the baseline, never inside a transform commit.
