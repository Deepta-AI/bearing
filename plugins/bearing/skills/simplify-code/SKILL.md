---
name: simplify-code
description: 'Deletes code a change does not need (dead code, one-use abstractions, unused options, redundant checks), tests green after each cut; refactor only moves code. Use when asked to "simplify this code" or "cut the bloat".'
argument-hint: "[<path or module> | --branch [<base>] | --repo]"
allowed-tools: Read, Edit, Grep, Glob, Bash(ls:*), Bash(wc -l:*), Bash(make check:*), Bash(make test:*), Bash(make fmt:*), Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git show:*), Bash(git merge-base:*), Bash(git rev-parse:*), Bash(git symbolic-ref:*), Bash(git ls-files:*), Bash(git grep:*), Bash(git apply:*), Bash(git rm -q:*), Bash(go test:*), Bash(go vet:*), Bash(go build:*), Bash(staticcheck:*), Bash(deadcode:*), Bash(pnpm exec tsc:*), Bash(pnpm exec vitest:*), Bash(pnpm exec knip:*), Bash(uv run pytest:*), Bash(python3 -m pytest:*), Bash(ruff check:*), Bash(vulture:*), Bash(./gradlew test:*), Bash(swift test:*)
---

# simplify-code

Generated code arrives with more than a person writing it by hand would
type: a factory for one type, an options struct nobody fills, a nil check
the types already rule out, a helper the standard library has. This skill
reads everything in scope first, decides for each unit whether it earns
its place, then deletes what does not, in steps the tests witness. The
measure is less code doing the same thing, not different code.

Not this: moving code without removing it (renames, extractions, splits)
is `refactor`; a cut that changes what a caller or user sees is a
feature change and is only proposed here.

## Inputs

- Scope: `$1`. A path or module; `--branch [<base>]` for what the
  current branch added (the common case: an AI-written change), base from
  `git symbolic-ref refs/remotes/origin/HEAD`, else `main`, `master` or
  `trunk`, whichever exists; `--repo` for everything `git ls-files`
  lists. Absent: the branch scope when the branch is ahead of its base,
  else one question: "which path or change should I simplify?".
- Check and test commands: `make check` and `make test` when the
  Makefile has them; else the stack's runner (`go test ./...`, `pnpm exec
  vitest run`, `uv run pytest`, `./gradlew test`, `swift test`); none
  found: stop, since nothing would witness the cuts.
- Justification sources: tests, `README*`, `docs/` (ADRs, API docs),
  `CHANGELOG*`, the ticket or PRD the branch names, and every file that
  can call code without an import: `scripts/`, `bin/`, the Makefile, CI
  files, Dockerfiles, cron and deploy manifests, entry points in
  `pyproject.toml` or `package.json`.
- Usage tools, used where installed and never required: `go vet`,
  `staticcheck`, `deadcode ./...`; `ruff check --select F401,F811,F841`,
  `vulture`; `pnpm exec tsc --noEmit`, `pnpm exec knip`. Otherwise
  `git grep -n` for each name, with the hit count printed.

## Steps

1. Baseline. `git status --porcelain`: save any work in progress with
   `git diff` to a patch outside the repository and note untracked paths;
   never stash it, and a file with the developer's edits is cut only
   where their hunks are untouched. Run the check and test commands and
   print "baseline: N passed, 0 failed" from the runner's summary. N=0 or
   any failure: stop and say so; simplifying on red hides what broke.
   Record lines and files in scope (`wc -l` on the scope's files; for a
   branch also `git diff --shortstat <base>`).
2. Read every file in scope in full; a diff hunk is not enough, read the
   whole file it sits in. Build the inventory, one row per unit: function
   or method, type or interface, file, config key, environment variable,
   flag, dependency, test, comment block. For each: what it does, who
   calls or reads it (grep the name across the whole repository, not the
   scope, and the files listed under Justification sources), and what
   justifies it (a test, a doc line, a ticket, an outside caller). Print
   "inventory: U units in F files". U=0: stop with "nothing in scope".
3. Decide each unit: keep, cut, inline or merge, with a one-line reason
   naming the evidence. Candidates, in the forms they take:
   - unreachable or unused: no caller, a branch whose condition cannot
     hold, a flag nobody sets, a dependency imported for one call the
     standard library already makes;
   - a single implementation behind an interface, factory, registry,
     builder, manager or wrapper, with one caller (Go interface plus
     `NewXxx` returning it, a Python abstract base with one subclass, a
     TypeScript class wrapping two functions): inline to the concrete
     thing;
   - speculative generality: an options struct, keyword argument,
     config key or parameter every caller passes the same value for, or
     none sets;
   - defensive checks for states the types or the only caller already
     rule out (nil on a value type, empty checks before a loop that
     handles empty, re-validating what the constructor validated);
   - duplication: a helper that reimplements the standard library
     (`strings.TrimSpace`, `max`, `slices.Contains`, `str.removeprefix`,
     `Array.prototype.includes`) or an existing helper in the repository;
   - error handling that adds nothing: `try`/`except` or `catch` that only
     rethrows, a wrapper function that only forwards its error; a
     log-and-continue that hides a failure is a proposal (removing it
     changes behaviour);
   - comments that restate the line below, section banners, logging that
     repeats the return value, docstrings that echo the signature;
   - tests that assert the mock rather than the code, or pin a unit being
     cut; kept tests are never weakened.
   Keep, and say why: error handling at real boundaries (file, network,
   database, process, user or request input); security, authorisation
   and validation checks; anything a test, script, doc, ADR or outside
   caller relies on; logs and metrics that alerts or dashboards read.
   Public API that code outside the repository may use (exported names
   that existed before the branch, published packages, HTTP routes, CLI
   flags, config keys a deployment sets) is never cut silently: it becomes
   a proposal. A cut that changes output, an error text, a status code,
   timing or order a caller can see is a proposal, not a cut.
   Print the decision table and its counts before touching code.
4. Apply the cuts in steps, one kind per step, in order: unused code,
   then collapsed abstractions, then unused options, then redundant
   checks and handlers, then comments and logging. For each step: Edit
   (whole files go with `git rm -q`); `make fmt` when present; the check
   and test commands; print "step K: -L lines, tests N passed". Red:
   `git apply -R` your step's patch (saved with `git diff` before the
   next step), move those cuts to proposals with the failure as the
   reason, continue. A step over about 300 changed lines is split.
5. Behaviour gate before each step is kept: no existing test assertion
   changed or deleted except in a test of a unit this step removed; no
   golden file, fixture, doc or contract from step 3 changed; the test
   count falls only by tests of removed units, each named.
6. Final: check and test commands once more; lines and files after,
   measured as in step 1; confirm the work in progress still equals the
   saved patch. Commit nothing. Print the commit command with the paths
   named, one per step when the developer wants the steps as commits.

## Output contract

```
## Simplify: <scope> (base <sha> for a branch)
Baseline: N passed, 0 failed   After: M passed, 0 failed (N - R removed with their units: <names>)
Lines: B -> A (-D)   Files: F -> G   Branch diff vs base: +x/-y -> +x'/-y'
Inventory: U units: K kept, C cut, I inlined, G merged, P proposed
| Step | Kind | Units | Lines | Tests |
| Cut | Unit (path:line) | Reason and evidence |
| Kept on purpose | Unit | Why (boundary, test, caller, doc) |
| Proposed, not applied | Unit | What would change, for whom |
Not run: <each tool or check skipped, and why> | none
Work in progress: untouched | none found
Noticed: <out-of-scope excess, pre-existing problems> | none
Commit (not run): git add <paths> && git commit -m "refactor(<scope>): remove <what>"
```

## Gotchas

- Grep misses callers that name things as strings: reflection, `getattr`,
  dependency injection containers, plugin registries, `init()`
  registration, template fields, route tables, serialisers reading
  field names, and a script or cron job outside the source tree. A zero
  hit count means "no caller found", so search those places before a cut.
- "The types rule it out" must be true at every call site, including
  ones outside the scope. A nil check on a pointer an HTTP decoder fills
  is a boundary check, not noise.
- A test that pins a behaviour pins it on purpose even when the code
  looks odd. The odd code stays; say what the test pins.
- Deleting a test because its unit was cut is fine; deleting one because
  it failed after a cut is the cut changing behaviour. Undo the cut.
- An interface with one implementation in the repository may have a
  second one in a test, a mock generator config or another service.
  Check before collapsing it.
- In branch scope, code the branch did not add is out of scope even when
  it is bloated; list it under Noticed, do not cut it.
- A standard call replaces a helper only if they agree on every input:
  Python's `round()` on a `Decimal` rounds half to even where the helper
  may round half up, `strings.Trim` is not `TrimSuffix`, `Math.max()` of
  nothing is `-Infinity`. Check the edge inputs; tests rarely cover them.
- A shorter version that is harder to read is not simpler. Cut units,
  do not golf expressions.
- Removing a dependency means its manifest and lock file lines too, and
  nothing else in the repository importing it.
