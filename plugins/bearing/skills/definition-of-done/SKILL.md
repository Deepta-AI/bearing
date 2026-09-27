---
name: definition-of-done
description: 'Checks a branch or ticket against the Definition of Done, with evidence per item: gate, tests, docs, scope, commits, smoke run. Use when asked "am I done", "is this story complete" or "ready to merge?"'
argument-hint: "[base branch, default: the state file's Base line, else develop, else main]"
allowed-tools: Read, Grep, Glob, Write, Skill, Bash(make:*), Bash(docker compose:*), Bash(curl:*), Bash(playwright-cli:*), Bash(pnpm exec playwright:*), Bash(git status:*), Bash(git am:*), Bash(git checkout:*), Bash(git switch:*), Bash(git branch:*), Bash(git worktree:*), Bash(git diff:*), Bash(git log:*), Bash(git remote:*), Bash(git rev-parse:*), Bash(git show:*), Bash(go vet:*), Bash(go test:*), Bash(go run:*), Bash(go build:*), Bash(pnpm test:*), Bash(uv run pytest:*), Bash(pytest:*), Bash(python3 -m pytest:*), Bash(./gradlew test:*), Bash(swift test:*), Bash(tail -40), Bash(bash *skills/definition-of-done/scripts/red_proof.sh *), Bash(bash *bin/brg-state-path*), Bash(python3 *skills/prose-lint/scripts/prose_check.py*)
---

# definition-of-done

Every item gets one of `pass`, `fail`, `n/a`, and the evidence: a command
and its output, or a file and line. An item without evidence is `fail`.
The list below is the standard's; it needs no file in the repository.

## Inputs

- base branch: the argument, or the base the user named in the request;
  else the state file `.bearing/state/<branch with / as _>.md` (`bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-state-path"` prints it)
  (`Base:` line); else the first of `origin/develop`, `develop`,
  `origin/main`, `main` that `git rev-parse --verify -q` finds (a repository
  with no remote still has local branches); else the HEAD branch from
  `git remote show origin`; else the current branch's upstream. Say which
  was used and why.
- red proof: `scripts/red_proof.sh` in this skill, bash and git only.
- task id: the branch name (`[A-Z][A-Z0-9]*(-[0-9]+)+`); if absent, the
  state file; if absent, ask once; if none, items 10 and 11 check scope
  against the stated task and commits without an id, and the table
  header says "no task id".
- gate: `make check` when the Makefile has a `check` target; if absent,
  the stack's native command (`go test ./...`, `pnpm test`, `uv run
  pytest`, `./gradlew test`, `swift test`); item 1 then
  says "improvised gate" (`new-repo` or `onboard-repo` install the
  Makefile).
- the list: the thirteen items in step 3, which are the standard's and
  need no file in the repository; a "Definition of done additions" section
  in AGENTS.md, when present, may add items to them and never removes one.
- event sheet: `docs/analytics/EVENT_SHEET.md`; if absent and the diff
  adds events, item 6 fails with "no event sheet; `analytics-events` writes
  one".
- the task's statement: the state file's acceptance criteria; if absent,
  the MR or commit bodies; if absent, ask once what the task was.

## Steps

1. Establish the diff: `git diff --stat <base>...HEAD` and `git log
   --oneline <base>..HEAD`. Zero files: stop with "0 files in diff
   between <base> and HEAD".
2. Run the gate: `<command> 2>&1 | tail -40`. The tail is the evidence
   for item 1.
3. Walk the list. For each:
   1. gate: the tail above; `make check` must end with `check: passed`,
      a native command must exit 0. Then run the gate on the base too and
      compare what each checked (files linted, tests collected: `pytest
      --collect-only -q`, `go test -list . ./...`): a branch that passes by
      making the gate check less (an exclude, a skip, a narrowed path) has
      not passed it.
   2. tests: open the test files in the diff; for a bugfix branch there
      must be a test that names the bug or the task id, and it must be
      proven red without the fix. A bugfix branch is a `bugfix/` or
      `hotfix/` branch, or one with a `fix:` commit in the range. Run
      `bash "${CLAUDE_PLUGIN_ROOT}/skills/definition-of-done/scripts/red_proof.sh" <base> '<the narrowest command that runs that test>'`
      (`go test -run '^TestTC0012' ./internal/auth/`, `pnpm exec vitest
      run src/auth/login.test.ts`, `uv run pytest tests/test_login.py::test_tc_0012`).
      It runs the test in a throwaway worktree of HEAD (must pass), puts
      every non-test file back to the base (must fail), and never touches
      the working tree. Its last line is the evidence; "GREEN without the
      fix" is a fail, since the test would have passed before the bug was
      fixed and so does not guard against it. "RED FOR THE WRONG REASON"
      is a fail too: the test file imports or calls something the fix
      added, so without the fix it never loads or builds and its
      assertions never meet the bug. Say which symbol, then check the
      assertions that exercise the buggy behaviour against the base code
      by hand (the base version of the function in a scratch copy, or
      those assertions alone) and report whether they would have failed;
      a red proof is only an assertion failing on the bug's input.
      For every branch, a test in the diff counts only if the gate runs
      it: find each new test's name in the gate's collected or verbose
      output. A file the runner never collects (a name outside pytest.ini
      `python_files`, a Go build tag, a `skip`, `xfail`, `t.Skip` or
      `.only`) leaves its behaviour untested; run it directly and report
      what it does.
   3. schemas: every new or changed handler, route, screen or message has
      a schema at the boundary (grep for the schema next to the handler).
   4. errors: new error paths wrap and map; grep for bare `err` returns,
      empty catches, `except:` and `catch {}`. A new handler must answer
      errors the way the API documents and the existing handlers do (the
      repository's own mapping helper, the documented status and body),
      never pass an internal error's text to the client: grep the diff
      for `err.Error()` in a response (`http.Error(w, err.Error(), ...)`),
      `str(e)`, `repr(e)` or `err.message` in a response body, and
      `traceback` in a response. A not-found from the store that reaches
      the client as a 500 is a fail.
   5. observability: a new endpoint or job logs with a request id and has
      a metric; say which lines. Judge by what the repository already has:
      a middleware that wraps the whole mux covers a new route, and where
      the repository has no metrics anywhere this is `n/a` with that
      reason (a gap to note, not this branch's failure). The same holds
      for every item: never fail a branch for a practice its repository
      does not have.
   6. analytics: if events were added, they are in the event sheet.
   7. no new dependency (diff of package.json, go.mod, pyproject, gradle,
      Package.swift), no `eslint-disable`, `nolint`, `noqa`, `@Suppress`,
      `swiftlint:disable`, no lowered threshold in configs.
   8. `.env.example` updated if config was read; absent file plus a new
      config read is a fail. A new entry must also load the way the
      repository loads `.env` (a Makefile that sources it with `.` is a
      shell: an unquoted value with spaces runs a command and leaves the
      variable unset); load it and print the value to prove it.
   9. docs: README, ADR, runbook where the change warrants; say which.
   10. scope: every changed file traces to the task; list any that do not.
   11. commits: Conventional, `[ID]` when an id exists, no AI trailer
       (`git log --format=%B`).
   12. prose: the em dash and the other prose tells over the changed
       files, found by the prose lint script:
       `git diff --name-only <base>...HEAD | python3 "${CLAUDE_PLUGIN_ROOT}/skills/prose-lint/scripts/prose_check.py" --files-from -`.
       It reads `.md` and UI string files by path, fails on any hit and
       on zero files; its `prose-lint:` counts line is the evidence.
       No changed file it can read: `n/a: no prose changed`.
   13. smoke: `make check` proves the tests, not the product; unit tests
       run against mocks and test-only settings, so a wrong production
       build setting passes all of them. When the repository ships
       something runnable (a compose file, a Dockerfile, or a `make up`
       or `make dev` target), start it the way a user does (`make up`,
       else `docker compose up -d --build --wait`, else `make dev`) with a
       local `.env` from `.env.example` and a throwaway test login the run
       creates. Then drive the main flow of what changed end to end
       against the real backend, with no route mocks. A start that
       fails (a panic, an exit before the port listens) is a fail with
       its output as the evidence, since the tests never built what the
       entry point builds. Drive it with a browser for a UI
       (the playwright-cli skill, or a Playwright script with no
       `page.route`), `curl` for an API. Sign-in comes first whenever the
       product has one. Record every request to the app's own origin as
       method, path and status. A request fails on a 404, 405 or 5xx, on
       a path that repeats a segment (`/api/api/`), or on a console error
       the flow did not expect. Write `.scratch/smoke-<ID>.md` with the
       requests and the last line `smoke: N requests checked, F failed`,
       then stop what you started (`make down`, `docker compose down`, or
       the process a `make dev` started) and show that the port is free.
       autopilot's dod gate reads that line and refuses N = 0, F > 0
       or a file older than the last commit. Headless under the
       sandbox (`BRG_AUTOPILOT_HEADLESS=1`): do not start the stack;
       write the checks to `.scratch/smoke-plan-<ID>.txt`, run
       `brg-autopilot smoke-request --id <ID>` and end the turn; the
       launcher runs it and writes `.scratch/smoke-<ID>.md`. Nothing
       runnable: `n/a: nothing to run` naming what was looked for.
4. Print the table, then the verdict: `done` only if no `fail`. Each
   failing row names the file and the function, route or line, so the
   author can act without searching, and says what was run to show it.

## Output contract

```
## Definition of done: <ID or "no task id"> (<N> files, <M> commits, base <base>)
| # | Item | Result | Evidence |
...
Verdict: done | not done (K items failing)
```

## Gotchas

- Never mark an item `pass` on the strength of a claim in the conversation.
- `n/a` needs a reason ("no config read", "no events added").
- If the gate fails on something unrelated to the branch, the verdict is
  still not done; report it under Not done with the failing target.
- An improvised gate proves tests, not lint or thresholds; items 7 and
  12 need their own greps in that case, and the verdict says the gate
  was improvised.
