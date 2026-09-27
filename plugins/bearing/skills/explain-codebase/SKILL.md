---
name: explain-codebase
description: 'Explains how a repo or feature works, read-only, path:line for every claim: entry points, module map, one request traced. Use when asked "how does this work", "where is X handled" or "trace this request".'
argument-hint: "[question, subsystem or path; default the whole repo]"
context: fork
agent: explorer
allowed-tools: Read, Grep, Glob
---

# explain-codebase

A map with coordinates. Every claim names a file and a line so the
reader can check it in one keystroke instead of trusting it. The value
is not the map, which any careful reader produces; it is the handful of
things a careful reader misses: where the data really comes from, what
a failed side effect really does, and every copy of a rule someone is
about to change.

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
- Claims to check: `README.md`, `CONTRIBUTING.md`, `CHANGELOG.md`,
  `CLAUDE.md`, `AGENTS.md`, `docs/`, code comments on the lines you cite.
  Every one is a claim about the code, not evidence of it.
- One request or job to trace: named in the question; for the whole
  repo, the first route or command reached from the first entry point.
- Nothing else. No build, no test run, no write: not even a notes file.

## Steps

1. Inventory: top-level directories and source files per language
   (Glob), excluding `node_modules`, `vendor`, `dist`, `build`,
   `.venv`, generated files. M=0 source files: stop with "0 source
   files under <path>; nothing to explain". A repository under about
   40 source files is read whole; above that, read the trace and grep.
2. Entry points, one `path:line` each, and which process each one is.
   Note which processes share state (a file, a table, a cache) and how
   each reads it: loaded once at start, or read per request.
3. Trace the request or job end to end: entry, routing, handler,
   service, store, response or side effect, each `path:line`. Then
   follow the record it writes to every reader of it (a worker, a
   report, an export): the trace ends where the effect leaves the
   system, not at the insert.
4. Close the three gaps a single trace leaves open:
   - Other writers. Grep every caller of the write the trace ends in.
     Each other entry that reaches it is a line naming the checks it
     skips and what the downstream reader then does with its records.
   - Inputs of the rules. For every value a check reads (a price, a
     balance, a flag, a status), grep who writes it. If only tests or
     fixtures write it, say so: the data arrives from outside the
     repository, and you do not guess from where.
   - State with no exit. For every status or state value, grep who
     sets it. A state nothing moves out of is a dead end; say what
     happens to records that reach it.
5. Side effects that leave the process (payment, email, HTTP call,
   message): name what is caught, what is retried, and when the record
   is marked done. A timeout, a reset connection or a crash after the
   call is an unknown outcome, not a failure: the other side may have
   acted. Retrying it without an idempotency key the other side honours
   repeats the effect. Check the key in the request itself; a changelog
   or comment saying one exists is not the request.
6. Claims versus code: for each claim from Inputs that the question
   touches, and always for how to run it, where config comes from and
   test naming, mark it `match` or `drift` with both locations. Report
   drift; do not pick a side.
7. Where to change X, only when the question names a change:
   - Find every copy of the rule, not the first. Grep the value in each
     spelling and unit (`10000`, `10_000`, `10,000`, the same amount in
     cents or thousands, an argument to a unit-conversion helper), grep
     the comparisons on the field, and read each reader found in step 4. Copies in prose
     (messages, docs, UI text) count.
   - For each copy give the operator (`>` or `>=`) and the new value in
     that copy's own unit. Copies that disagree at the boundary are a
     question for the requester, asked with the exact amount.
   - A config key, flag or env var that looks like it controls the rule
     but is never read: say an edit to it changes nothing.
   - Tests: those whose assertions fail, and those whose inputs stop
     exercising the case (an amount now under the new limit, a fixture
     too small to reach it). Name each by function.
   - Data already stored under the old rule: the change does not
     re-evaluate it; say what moves it, or that nothing does.
8. Check before answering. Re-open every cited line and confirm it says
   what the sentence claims. Cut anything that describes a component the
   repository does not contain (a database, queue, approval screen,
   auth layer) or say plainly that it is absent.

## Output contract

Lead with the direct answer in two or three lines, then:

```
## Explain: <question | the whole repo>
Answer: <the direct answer, with path:line>
Entry points: <path:line> <process, what it does>; ...
Trace (<request or job>): <path:line> -> <path:line> -> ... -> <effect leaves the system>
Other writers: <path:line> <checks skipped, what happens downstream> | none
Where the data comes from: <value>: <writer path:line> | written only by tests: from outside the repo
Side effects: <call path:line> <caught, retried, marked done when; unknown-outcome behaviour>
Dead-end states: <state>: <nothing moves it | path:line> | none
Claims vs code: <claim doc:line> | <code path:line> | match|drift
Change X: <path:line> <operator> <old> -> <new in its unit> (tests: <fn> fails | <fn> stops exercising); ...
  Not read: <config key>; Already stored: <what happens>; Ask: <boundary question> | not asked
Risks (read, not run): <path:line> <what goes wrong>; ... | none
Unconfirmed: <only what the code cannot settle> | none
```

Omit a line whose answer is "none" and the question did not ask about.
Under 60 lines; a small repository gets a short map.

## Gotchas

- A line without a `path:line` is an opinion. Cut it or find the line.
- The trace is not done at the insert. The question "what happens when
  X is created" is answered where the money, message or file leaves.
- The check you traced is only as good as its inputs. "Refuses to
  overdraw" means nothing until you know who writes the balance.
- "On error, retry next poll" reads as safe. After a timeout it is how
  an email, a charge or a payout happens twice.
- A changelog entry is the loudest drift: it names a version, so readers
  believe it. Verify each one the question touches.
- A limit is rarely one constant. Different units and operators in two
  copies are the normal case, and each needs its own new value.
- Processes that each load a shared file once disagree about it from
  the first write; the last whole-file save wins.
