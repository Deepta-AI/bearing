---
name: traceability
description: 'Builds the traceability matrix from requirements through stories, test cases, tests, commits and tickets, counting every gap; read-only. Use when asked "is everything traced", "traceability matrix" or "untested".'
argument-hint: "[base branch for a branch audit; omitted, the whole history]"
allowed-tools: Read, Write, Grep, Glob, Bash(bash *bin/brg-tracker *), Bash(ls:*), Bash(mkdir:*), Bash(rm:*), Bash(git log:*), Bash(git rev-list:*), Bash(git branch:*), Bash(git merge-base:*), Bash(git diff:*), Bash(git show:*), Bash(git status:*), Bash(make check:*), Bash(make test:*), Bash(go test:*), Bash(pytest:*), Bash(npm test:*), Bash(python3 *skills/traceability/scripts/trace_check.py*)
---

# traceability

The chain is REQ, US, AC, TC, test, commit and MR, tracker ticket, docs,
event. The gate walks it with exact ids and counts the broken links. The
ids are the easy half. The half that decides a sign-off is whether each
link is true: a test that names an AC but asserts something else, a
skipped test, a tested function nothing calls, a coverage document that
says "all covered". This skill reports; it does not repair.

## Inputs

- The question decides the scope, before anything is read:
  - a branch or MR ("before I raise the MR", "is this branch traced"):
    base = the target branch (`main` unless the repo says otherwise).
    Only the stories the branch touched are in scope; everything else is
    context, reported apart and never in the verdict.
  - a release sign-off or "is everything traced": the whole history of
    the release branch, every active story in scope.
- The repo's conventions: CLAUDE.md, README, CONTRIBUTING. They say which
  tracker is used (`Tracker: none` means no ticket gaps), how commits and
  tests name ids, and which documents the team keeps. A document the team
  says it does not keep is the basis of your judgement, not a gap to fix.
- Product docs: `docs/product/PRD.md`, `docs/product/backlog.md`,
  `docs/product/coverage.md`, `docs/testing/test-cases.md`; design and
  operations: `docs/adr/`, `docs/design/`, `docs/runbooks/`,
  `docs/analytics/EVENT_SHEET.md`. Each is read or missing; missing is
  never a stop.
- Tracker and prefix: `bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-tracker"
  config` (`tracker:` and `id prefix:` lines); if the script is absent,
  CLAUDE.md; otherwise the gate infers a prefix from commit subjects.
- Gate: `scripts/trace_check.py` in this skill, Python 3, run from the
  repository root. It runs `git log` itself, from the merge base with
  `--base`, else every commit including the root.
- Template: `templates/traceability.md`, for a written matrix.

## Steps

1. Scope and conventions. Decide branch or full audit from the question.
   For a branch: `git merge-base <base> HEAD`, then
   `git log --oneline <base>..HEAD` (the branch's own commits) and
   `git log --oneline HEAD..<base>` (commits on the base since the branch
   was cut: not the branch's, and the branch is behind by that many).
   Never compare `git diff <base> HEAD` two-dot: it shows the base's newer
   work as the branch deleting it. Read CLAUDE.md for tracker and id rules.
2. Run the gate:
   `python3 "${CLAUDE_PLUGIN_ROOT}/skills/traceability/scripts/trace_check.py" --base <base>`
   for a branch, without `--base` for a full audit; add `--prefix <P>`,
   `--tracker none`, or `--prd`, `--backlog`, `--coverage`, `--cases`
   for other paths. It prints `problem:` lines for gaps in scope,
   `outside scope:` lines, `review:` lines for boundary changes no ADR
   asks about, `not run by default:` lines for test files behind a build
   tag or a deselected marker, one `tests:` line per story in scope
   naming the test functions that carry its id, then the `Scope:`, `Ids:`, `Links:`,
   `Gaps:`, `Unknown tickets:` and `traceability:` lines and the
   verdict; exit 1 on any gap in scope or on empty input. Gap classes:
   REQ without story, story without AC, AC without TC, TC without test,
   TC test skipped (a skipped function links nothing), story without test
   (when there is no test-case document), unknown id (a US or TC id in a
   test or commit that no backlog row or case holds), coverage claim
   contradicted, story without ticket, ticket without commits, commit
   without id, boundary change without ADR (only when an ADR asks for a
   record of that kind of change), event not in sheet, missing source.
3. Check each link is true. The gate matches ids; these are the checks it
   cannot make, and they are where a sign-off goes wrong:
   - Per AC in scope, open the test the `tests:` line names and read the
     assertion. An AC is tested only when an assertion checks its
     outcome; name the test function per AC. A test named for a story
     that asserts part of it leaves the rest untested. An AC about a
     total, a limit or a sequence ("together never exceed", "only once")
     needs a test that makes more than one call; one call over the limit
     proves the single-call guard, not the cumulative one.
   - Named is not run. A test counts only if the command the team runs
     executes it: check each credited function in the verbose run output
     (`go test -v`, `pytest -v`, the runner's list). Build tags, markers
     the config deselects, a package the make target leaves out, a file
     the runner's pattern misses: each hides a test the way a skip does.
     Run a hidden test once explicitly (`go test -tags <tag> ./pkg/`)
     and report whether it passes; a test nobody runs has often stopped
     passing.
   - An `unknown id` in a test beside a story with no test is usually one
     test carrying the wrong label: read its body, say which story and AC
     it really covers and that the label needs correcting. Never count
     that story as untested, and never as cleanly traced.
   - A skipped test: find why (the skip message; the commit that added
     the skip, `git log -S't.Skip' -- <file>` or its stack's marker).
     "Flaky" on a date, time zone, midnight or ordering case is usually a
     real defect. Establish it by working the code under test through the
     test's own input, or by running an unskipped copy you delete after;
     say which.
   - Tested is not delivered. For each requirement in scope, find the
     production caller of the tested code (Grep for the function outside
     test files; routes, handlers, jobs, main). A function only tests
     call delivers nothing, and an ADR saying where a rule is enforced
     ("checked on every request") is a claim to check the same way. A
     migration no code reads or writes is the same finding.
   - The case the AC implies that no test tries: repeat, boundary, other
     owner, zero, maximum, concurrency. For keys, locks and caches, ask
     what the key is scoped to (per payment, per user, global) and
     whether a second caller can collide. Probe with a throwaway test
     only if you delete it after; report it as a finding outside the ACs.
   - Documents that claim coverage (coverage.md, README, an MR
     description) are claims under audit, never evidence. Each claim the
     repository contradicts is a finding.
   - A commit in scope without the id the conventions require is
     untraced work: name the sha and what it changed, and say so when a
     skip, migration or behaviour change arrived in it.
   - A commit's id is a claim too. Read each in-scope commit's diff
     (`git show <sha>`) against the story it names: a behaviour change to
     another story's code, or a "refactor" that changes behaviour, is
     mistraced work. For every defect you find, name the commit that
     introduced it (`git log -p -- <file>`); that is usually where the
     trace broke.
   - A ticket named in a skip message, TODO or commit that no story holds
     is work outside the backlog: list it.
4. Run the tests (`make check` where the Makefile has it, else the
   stack's test command; add `-v` or the runner's verbose flag to see
   what ran) and state the command and the result. A green run with a
   skip, or with a test that never ran, is not a pass for that AC.
5. Write `docs/traceability.md` from the template only for a release
   sign-off or when the matrix is asked for; a branch check is answered
   in the reply. Never edit an audited file, never commit.

## Output contract

```
## Traceability: <branch <base>..HEAD, N commits, stories X, Y | full history from <sha>, N commits>
Verdict: <traced | not traced for <release or MR>: K blocking items>
Blocking, each with its action:
- <id>: <what is wrong, file and function> -> <add the test for AC-..., fix the label, fix the defect, write the ADR, ...>
Per AC in scope: <AC id> | <test function or none> | <asserted | partial | skipped | not run | untested>
Delivered: <requirement> | <production caller or none>
Also found (pre-existing, outside scope or outside the ACs): <items>
Tests: <command> -> <result>
Gate: <Scope:, Gaps: and Verdict: lines, verbatim>
Written: docs/traceability.md | none (answered here)
```

Every count in the reply is the gate's or one you computed and can show.
Withdrawn and retired items appear only as withdrawn or retired.

## Gotchas

- Scope follows the question. A branch audit that reports every AC in the
  backlog buries the three that matter; a release audit that reads only
  the last branch misses work merged earlier. Say which range you read,
  and count commits the way `git rev-list --count` does for that range.
- Blocking follows the question too. For an MR, blocking is what this
  branch gets wrong: its ACs without a running assertion, defects in its
  code, wrong labels, untraced or mistraced commits. "Not delivered" (no
  route, no caller, a table nothing reads) blocks a release sign-off; on
  a branch it blocks only when the branch's own stories promise
  reachable behaviour and no other active story holds the wiring. When a
  planned story holds it, name that story as context, not as a blocker.
- A missing source is not a pass, and not always a gap. No test-case
  document where the team keeps one: every AC is untraced. None where
  CLAUDE.md says stories are traced by id in tests: judge from the test
  bodies and say that was the basis.
- Every gap becomes an action someone can take: the test to add (for
  which AC, in which file), the label to change, the defect to fix, the
  record to write. A gap without its action is half a finding.
- A boundary change is an ADR gap when an ADR or convention asks for a
  record of it (the gate reads the ADR text for that). A migration an
  existing ADR already covers by its ticket is not a gap: do not
  over-report.
- Exact ids only. "the login story" in a commit body is not a link. Never
  invent ids; a proposed new story or case is labelled as proposed.
- Zero commits in range is a count to print, not an error.
