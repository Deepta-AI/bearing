# Worked example: devports, built with the kit

A real build, captured step by step: a Go command line tool that shows what is running on a developer machine (listening ports, containers, well known services, health probes, env files with variable names only). Every step below is the prompt the developer typed and the report the skill produced, unchanged apart from the home path. The tracker was `none`, so ticket steps were skipped with a note. The full transcripts, the tool and the recorded video tooling live in the `devports` repository under `docs/walkthrough/`.


## Step 01: new-repo (with tech-decision first)

Prompt:

```
/new-repo go-api Devports --host gitlab --tracker none --module example.com/devports
```

Report:

```
## New repo: Devports (go-api) at ~/Repos/devports
Decisions: 3 made, 0 on file, 3 deferred (ADRs: docs/adr/0001..0003)
brg-scaffold: 63 files written, 0 with unfilled placeholders (must be 0)
Gate: make check: passed
Tracker prefix: none   Module: example.com/devports   Lead, group: @lead, @engineering (placeholders)
Not done: first commit (git add -A && git commit -m "chore: scaffold Devports from bearing"), remote project creation, CODEOWNERS handles, CI variables
```

Files:

- 63 scaffold files (Makefile, AGENTS.md, CLAUDE.md, .claude/, .githooks/, .gitlab-ci.yml, .gitlab/, docs/, cmd/api, internal/, db/, go.mod, go.sum)
- docs/adr/0001-keep-no-database.md, docs/adr/0002-cli-with-json-output-as-the-interface.md, docs/adr/0003-use-go-with-the-standard-library.md (written by tech-decision)
- docs/decisions.md (decision log, 3 accepted rows, 3 deferred rows)
- CLAUDE.md (project snapshot filled: CLI, no database, entrypoint, what it talks to)


## Step 02: start-task

Prompt:

```
/start-task TASK-1 PortTable
```

Report:

```
## Task: TASK-1 PortTable
Branch: feature/TASK-1-PortTable from main (local)
State: .bearing/state/feature_TASK-1-PortTable.md   Criteria: 5
Tracker: none (any id)
Next: prd (the brief is one paragraph; normalise it before writing stories), then backlog, test-cases, then test-driven-development
```

Files:

- .bearing/state/feature_TASK-1-PortTable.md (git-ignored; the five criteria, Done, Next, Blockers)
- branch feature/TASK-1-PortTable created from main


## Step 03: prd

Prompt:

```
/prd .bearing/state/feature_TASK-1-PortTable.md
```

Report:

```
## PRD: devports, what is running on this machine (12 input lines from .bearing/state/feature_TASK-1-PortTable.md)
Statements extracted: 11 (REQ-001 to REQ-011, 0 withdrawn)
Ambiguous statements flagged: 2 (REQ-005 "go binaries by name", REQ-006 "services that answer HTTP")
Inferred items: 4 (persona, Windows non-goal, watch scope, Q4)   Open questions: 4
Could not extract: goal targets, owner and tracker epic
Written: docs/product/PRD.md
Critic: declined (walkthrough runs without the critic agent)
Verdict: normalised
```

Files:

- docs/product/PRD.md (new: 9 sections, 11 REQ statements, 4 open questions)


## Step 04: backlog

Prompt:

```
/backlog docs/product/PRD.md
```

Report:

```
## Backlog from docs/product/PRD.md: 11 REQ statements read
Judged: 11 (seed 7, criterion 3, variant 1, duplicate 0, split 0)
Epics: 2   Stories: 5   Acceptance criteria: 18   Flows: 2
Coverage: 11/11 REQ covered, 0 gaps, 0 orphan stories
Written: docs/product/backlog.md, docs/product/coverage.md,
         docs/product/user-flows.md
Verdict: covered
```

Files:

- docs/product/backlog.md (EP-01, EP-02; US-00-001 to US-00-005; 18 AC)
- docs/product/coverage.md (11 rows, 0 gaps, 0 orphans)
- docs/product/user-flows.md (F1, F2: 11 steps, 5 alternate paths, 7 error paths, 0 unhandled)


## Step 05: test-cases

Prompt:

```
/test-cases docs/product/backlog.md
```

Report:

```
## Test cases: backlog (docs/product/backlog.md)
Stories read: 5   ACs read: 18
Cases written: 41 (unit 41, integration 0, e2e 0, manual 0)
ACs with zero cases: 0
Files: docs/testing/test-scenarios.md, docs/testing/test-cases.md
Result: pass
```

Files:

- docs/testing/test-scenarios.md (5 story blocks, 0 needing rewording)
- docs/testing/test-cases.md (TC-0001 to TC-0041, all `planned`)


## Step 06: test-driven-development (Superpowers)

Prompt:

```
Use the test-driven-development skill. Build the packages in this order: envfiles, ports (fixture based),
services, probe (httptest), docker (parser over docker ps --format json lines), render, then the CLI wiring.
Commit after each green package with [TASK-1]. No network in unit tests.
```

Report:

```
PORT   ADDRESS     PID      PROCESS    SERVICE     HEALTH
53     127.0.0.53  0        ?                      -
631    127.0.0.1   0        ?                      -
5432   0.0.0.0     0        ?          postgres    -
6379   0.0.0.0     0        ?          redis       -
8080   ::          2598399  api-bin               -
8123   127.0.0.1   0        ?          clickhouse  -
8502   127.0.0.1   1953     streamlit              -
probes: skipped (--no-probe)

CONTAINER  IMAGE        PORTS  HEALTH   STATE
```

Files:

- Makefile, .gitlab-ci.yml, .golangci.yml, README.md, .env.example, CLAUDE.md (repointed at a CLI); cmd/api, internal/{config,health,httpapi,middleware,store,telemetry}, db/, sqlc.yaml, docker-compose.yml, Dockerfile removed
- internal/envfiles/{envfiles.go,envfiles_test.go}
- internal/ports/{ports.go,ports_linux.go,ports_darwin.go,ports_other.go,ports_test.go,testdata/tcp,testdata/tcp6,testdata/lsof.txt}
- internal/services/{services.go,services_test.go}
- internal/probe/{probe.go,probe_test.go}
- internal/docker/{docker.go,docker_test.go,testdata/ps.jsonl}
- internal/render/{render.go,render


## Step 07: logging

Prompt:

```
/logging cmd/devports --http
```

Report:

```
## Logging: go-api (0 handlers or screens found; 4 commands, 4 external calls)
Logger: internal/logging/logging.go (log/slog)
Request id: bound in cmd/devports/app.go (run_id per invocation)
| Boundary | Found | Entry and exit after |
| handlers or screens | 0 | 0 (CLI) |
| commands | 4 | 4 (start at debug, done at info) |
| external calls | 4 | 4 (debug with target and duration_ms) |
| jobs and consumers | 0 | 0 |
Findings: 0 stray print calls, 0 lines with PII or secrets
HTTP logging: installed in internal/probe/probe.go (LOG_HTTP default false)
gate: make check: passed (check: 5 gates run, 0 skipped)
```

Files:

- internal/logging/{logging.go,logging_test.go} (new)
- internal/probe/{probe.go,probe_test.go} (Logger, LogHTTP, one line per probe)
- cmd/devports/{app.go,app_test.go} (--verbose, run_id, boundary lines, getenv dependency)
- .env.example (LOG_HTTP with a comment; the two unread toggles explained)
- README.md (Logging section: how to flip LOG_HTTP at runtime)


## Step 08: test-run

Prompt:

```
/test-run
```

Report:

```
## Test run: feature/TASK-1-PortTable @ 5d254ec (go-api)
Suites: 1 present, 1 run, 0 not run
tests: 82 run, 82 passed, 0 failed, 0 skipped, coverage 88.9%
Per suite: unit 82/0/0  integration absent  e2e absent
Failures: none
Heal candidates: 0   Likely regressions: 0
Flaky candidates: 0 (every run 1 test repeated with the same result)   Slowest: TestTC0024SlowServerIsTimeout 0.02 s
Report: docs/testing/reports/2026-09-22-feature-TASK-1-PortTable.md (run 2 appended, + -run2.json)
```

Files:

- docs/testing/reports/2026-09-22-feature-TASK-1-PortTable.md (new; run 2 appended later)
- docs/testing/reports/2026-09-22-feature-TASK-1-PortTable-run2.json (run 2 model)
- docs/testing/reports/2026-09-22-feature-TASK-1-PortTable.json (new, the parsed model)
- docs/testing/test-cases.md (automation column: 41 rows `planned` to `automated`)
- .scratch/test-run/2026-09-22-feature-TASK-1-PortTable/unit.json (raw, git-ignored)


## Step 09: branch-review

Prompt:

```
/branch-review
```

Report:

```
## Review: main...HEAD @ a181e5c (77 files, 11 findings verified, 7 dropped as unverifiable)
Checklists: go, universal

HEAD moved twice while I read it (`6e70836` → `f655455` → `a181e5c`). All Go code below is as of `f655455`; the four later commits are docs, CHANGELOG and VERSION only. Findings 1 to 11 were re-verified against `a181e5c` by extracting the committed tree and running `go vet`, `go test -race` and the built binary outside the repo. Nothing in the repository was modified.

1. **[High] internal/ports/ports_linux.go:74  `owners()` lets the last pid in /proc directory order win a shared socket inode, so `free` names a worker instead of the process that holds the port.**
   Failure: every pre-fork server (nginx, gunicorn, php-fpm, uwsgi) shares one listening socket across master and workers. `out[inode] = Owner{...}` overwrites unconditionally while `fs.ReadDir` walks the pid directories in lexical order, so the last holder wins. Observed: a Python parent bound 127.0.0.1:19998 and forked (master 747391, workers 747400-747402); `devports free 19998` printed `held by pid 747406` and `kill 747406`. The developer pastes it, a worker dies, the master respawns one, the port is still held, and the tool that exists to answer "who has my port" answered wrong.
   Fix: when several pids share an inode keep the lowest, or the one whose ppid is not itself a holder, and print the rest as `pid N (+3 workers share this socket)`.

2. **[Medium] cmd/devports/app.go:358  `redactArgs` only matches names, so a credential inside a positional URI or attached to a short flag is printed in full.**
   Failure: the deny list is applied to the text before the first `=` of each token. Observed against the shipped helper: `psql postgres://app:hunter2@127.0.0.1:5432/app` passes through untouched, as do `redis-cli -u redis://default:hunter2@localhost:6379`, `curl -u admin:hunter2 ...` and `mysql -u root -phunter2`. `devports free 5432` then prints the password under `command:` on a screen share, which is exactly what the commit message claims it prevents.
   Fix: also redact by value shape, the userinfo part of any `scheme://user:pass@host` token and the tail of a `-p<value>` style flag, before joining.

3. **[Medium] cmd/devports/app.go:344,358  the deny list is applied to the executable path too, so the argument after it is replaced with `[redacted]`.**
   Failure: `isSecretName` is called on every token including argv[0]. Observed: `/opt/keycloak/bin/kc.sh start-dev --http-port 8080` prints as `/opt/keycloak/bin/kc.sh [redacted] --http-port 8080`, and `python -m authlib.server run --port 8000` loses `run`. Keycloak, authelia and anything with `key` or `auth` in its path hit this. The user reads a command line that is not the one running.
   Fix: only consider tokens that start with `-` or match `NAME=VALUE`, never argv[0] or a bare positional.

4. **[Medium] internal/envfiles/envfiles.go:55-70  a continuation line of a multi-line quoted value is parsed as an assignment, so part of the secret is printed as a variable name.**
   Failure: `ParseNames` is line based, and `f655455` raised the scanner buffer to 1 MB specifically so certificate lines are read. Observed with a `.env` holding a PEM block across three lines, the binary printed:
   `.env: CERT, MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA, API_KEY`
   The middle "name" is the body of the certificate. The package comment promises "a secret cannot reach the output by accident" and TC-0025 asserts it, but the assertion only covers single-line values.
   Fix: track the open quote. While a value started with `"` or `'` is unterminated, skip lines instead of parsing them as assignments.

5. **[Medium] cmd/devports/app.go:196  `printTable` drops the write error, so a failed table write is exit 1 in complete silence.**
...
```

Files:

- internal/ports/{ports.go,ports_linux.go,ports_darwin.go,ports_other.go,ports_test.go,ports_linux_test.go,testdata/proc/}
- internal/envfiles/{envfiles.go,envfiles_test.go}
- internal/probe/{probe.go,probe_test.go}, internal/docker/{docker.go,docker_test.go} (first pass)
- internal/services/{services.go,services_test.go}, internal/render/{render.go,render_test.go}, internal/logging/{logging.go,logging_test.go}
- cmd/devports/{app.go,app_test.go}
- docs/walkthrough/fixtures/proc/, README.md, .env.example (DEVPORTS_PROC_ROOT)


## Step 10: definition-of-done

Prompt:

```
/definition-of-done
```

Report:

```
## Definition of done: TASK-1 (176 files, 21 commits, base main)
| # | Item | Result | Evidence |
| 1 | gate | pass | `make check`: fmt-check 21 files, vet 8 packages, lint 8 packages (0 issues), test 8 packages, vuln 1 module; `check: 5 gates run, 0 skipped`, `check: passed` |
| 2 | tests | pass | 9 test files, 82 tests; 45 carry TC ids covering TC-0001 to TC-0041; every reviewer finding has a test written first (transcript 09) |
| 3 | schemas | pass | the JSON contract is render.Snapshot (internal/render/render.go), round trip tested (TC-0031); flags validated in parseArgs (cmd/devports/app.go), TC-0036 and TC-0040 |
| 4 | errors | pass | `grep 'return err$'` over non test code: 0 bare returns; every boundary failure becomes a note or a wrapped error; table and json write errors logged once (finding 5) |
| 5 | observability | pass | run_id bound in cmd/devports/app.go run(); boundary lines target=proc, http, docker, env with duration_ms; no metrics (a CLI, n/a) |
| 6 | analytics | n/a | no events added; docs/analytics/EVENT_SHEET.md untouched |
| 7 | dependencies and suppressions | pass | go.mod diff removes 36 lines and adds none; `grep nolint` over *.go: 0; no threshold lowered |
| 8 | .env.example | pass | LOG_HTTP and DEVPORTS_PROC_ROOT documented with a comment each; the two unread toggles explained |
| 9 | docs | pass | README (run, flags, testing hook, logging, layout), ADR-0001 to 0003, docs/product/*, docs/testing/* with the two-run report; runbook n/a (no service to operate) |
| 10 | scope | pass | every changed file traces to TASK-1: code, product and testing docs, the walkthrough transcripts and fixtures the brief asks for; the video tooling commit 2af9511 came from the other session on the same task |
| 11 | commits | pass | 21 subjects Conventional with [TASK-1] (grep offenders: 0); `git log --format=%B` has 0 AI trailers |
| 12 | prose | pass | `grep -P '\xE2\x80\x94'` over the changed .md files: 0 |
Verdict: done
```

Files:

- none changed (a read-only walk; the evidence is commands and their output)


## Step 11: merge-request

Prompt:

```
/merge-request
```

Report:

```
## MR: feature/TASK-1-PortTable -> main (TASK-1)   host: gitlab
Branch name: ok   Tree: dirty (5 files, another session's walkthrough tooling; no code)
Diff: 176 files, +6453 -1089 (split proposed: no; the commits are the split, reason in Approach)
Gate: make check: passed
Commits: 21 (offenders: 0)
Description: .scratch/mr-TASK-1.md
Ticket: tracker: none
Push: git push -u origin feature/TASK-1-PortTable
MR: <remote web url>/-/merge_requests/new?merge_request[source_branch]=feature/TASK-1-PortTable
  (no remote is configured yet; create the project on the git host, `git remote add origin <url>`, then push)
After opening it: tracker-sync trace TASK-1 --mr <url>   (skipped with tracker: none)
```

Files:

- .scratch/mr-TASK-1.md (git-ignored; the filled merge request description, regenerated after the reviewer round)


## Step 12: release

Prompt:

```
/release
```

Report:

```
## Release: v0.0.0 -> v0.1.0 (minor, branch main via feature/TASK-1-PortTable)
Commits since v0.0.0: 23 (feat 9, fix 4, changed 1, unclassifiable 0)
CHANGELOG.md: section regenerated   Version file: VERSION unchanged (0.1.0)
Gate: make check: passed
Commands for the engineer:
  git add -A && git commit -m "chore(release): v0.1.0"
  git tag -a v0.1.0 -m "v0.1.0"
  git push origin main --follow-tags
```

Files:

- CHANGELOG.md (v0.1.0 section regenerated after the reviewer round)
- VERSION (0.1.0, unchanged)


## Step 13: session-handoff

Prompt:

```
/session-handoff "Engineer: push the branch and open the MR from .scratch/mr-TASK-1.md"
```

Report:

```
## Handoff: .bearing/state/feature_TASK-1-PortTable.md (28 lines, limit 60)
Branch: feature/TASK-1-PortTable   Task: TASK-1   Base: main   Gate: passed
Next:
- Engineer: create the project on the git host, add the remote, push the branch, open the MR from .scratch/mr-TASK-1.md
- After the merge, on main: tag v0.1.0 and push with --follow-tags
- Walkthrough: the other session commits its video tooling under docs/walkthrough/
Files touched: 5 (the other session's, none of them code)   Blockers: 0   Open questions: 3
```

Files:

- .bearing/state/feature_TASK-1-PortTable.md (git-ignored; rewritten in the handoff shape, 28 lines)


## Step 14: make check and git log (closing summary)

Prompt:

```
make check && git log --oneline
```

Report:

```
fmt-check: 21 files checked
vet: 8 packages checked
0 issues.
lint: 8 packages checked
ok  	example.com/devports/cmd/devports	1.031s	coverage: 86.4% of statements
ok  	example.com/devports/internal/docker	1.020s	coverage: 82.7% of statements
ok  	example.com/devports/internal/envfiles	1.021s	coverage: 96.0% of statements
ok  	example.com/devports/internal/logging	1.015s	coverage: 91.7% of statements
ok  	example.com/devports/internal/ports	1.020s	coverage: 87.4% of statements
ok  	example.com/devports/internal/probe	1.049s	coverage: 93.5% of statements
ok  	example.com/devports/internal/render	1.023s	coverage: 73.6% of statements
ok  	example.com/devports/internal/services	1.019s	coverage: 100.0% of statements
test: 8 packages checked
No vulnerabilities found.
vuln: 1 modules checked
check: 5 gates run, 0 skipped
check: passed

5d254ec feat(ports): add DEVPORTS_PROC_ROOT and a curated proc fixture tree [TASK-1]
1647818 fix(cli): log table write errors, skip non HTTP probes, clear only a tty [TASK-1]
de8605f fix(cli): redact by value shape and dedupe free holders by pid [TASK-1]
9983bd2 fix(envfiles): skip the continuation lines of a quoted value [TASK-1]
2af9511 docs(walkthrough): add the scene definitions and the video build tooling [TASK-1]
a181e5c docs(walkthrough): correct the fmt-check, handoff and commit counts [TASK-1]
...
```

Files:

- docs/walkthrough/transcripts/08 to 14 (regenerated), docs/testing/reports/* (run 2), CHANGELOG.md (this step's commit)
