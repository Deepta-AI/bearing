# Quality phases: a testing phase and code review in every flow

Status: draft for review, 2026-10-17. Branch `feat/QualityPhases`, from
`origin/main` at v0.8.0. Sub-project 3 of 4 in the Bearing improvement
programme. Sub-project 2 (design pipeline, `feat/DesignPipeline`) is in
flight; section F says how the two merge.

The user skipped the brainstorming questions. Every choice below that is
not quoted from the user is marked **author's call**. Facts about the
repository are cited by path. Decided by the user on 2026-10-18: item 14
of definition of done may leave a suite that cannot run locally to a named
CI job, after one AskUserQuestion, recorded in the state file.

## Intent

The user's words, which bind this design:

- (5) "Workflows does not have testing phase. Test artifact generation is
  there, but testing (all types UI, regression, API, visual regression
  etc)" is missing.
- (6) "Workflow does not have code review phases."

What the repository shows behind those words:

- The flows in `docs/flows.json` generate tests (`test-cases`,
  `test-automation`) but no greenfield, feature or bug fix step runs them.
  `test-run` appears only in the inherited flow (steps `suite`, `baseline`).
- `make check`, the gate every flow and `definition-of-done` rely on, runs
  unit tests only. The stack templates mark `test-e2e`, `test-visual`,
  `test-integration` and `test-ui` "a CI job, not part of check"
  (`plugins/bearing-apps/skills/react/templates/Makefile:92,107`,
  `plugins/bearing-backend/skills/go/templates/Makefile:77`,
  `plugins/bearing-apps/skills/android/templates/Makefile:91`). So UI, API,
  visual and full regression suites first run in CI, after the MR is open.
- Bug fix and feature flows have `branch-review`; greenfield has none of
  its own (it links to the feature flow per task, but nothing reviews the
  release as a whole).
- Autopilot's `review` gate passes on any folder under `.scratch/review/`
  (`plugins/bearing/bin/brg-autopilot:696`), so a review that found
  blocking bugs, or one that reviewed nothing, passes it. No autopilot
  stage runs the e2e, visual or integration suites.

Why it matters: a branch can reach "done" and an MR with its UI, API and
visual suites never run and its review findings unread. The team also
asked for speed (v0.8.0 was a speed release), so the testing phase must be
scoped to the change while work is in progress, and run in full once, at
definition of done.

## Goals

1. Every task flow has a named testing step that runs the suites the
   change touches, across the layers the user named: UI, API, visual
   regression, and unit; and a full regression run before done.
2. Every task flow has a code review step, and greenfield reviews the
   release as a whole before it is cut.
3. The in-progress test run is fast: it runs only the layers and tests the
   diff touches, and never reruns what `make check-changed` already ran.
4. The full run happens once, inside `definition-of-done`, and its
   evidence is on disk for HEAD.
5. Autopilot enforces both: a `test_run` stage, a review gate that reads a
   verdict, and a dod gate that reads the full run.

## Non-goals

- New test frameworks or new Makefile targets in the stack templates. The
  suites and targets that exist are the ones run.
- Writing tests. `test-cases` and `test-automation` stay as they are.
- Load and resilience testing as a default step. They join as optional
  steps only (B4).
- Changing `make check` to include e2e, visual or integration suites. It
  stays the fast gate the Stop hook runs.
- Re-reviewing after review fixes (author's call, for speed; C2 keeps the
  fixes accountable instead).
- `merge-request` quoting the review verdict (worth doing later; out of
  scope here, author's call).

## Anti-goals

- A testing step that runs every suite on every edit. That is the slowness
  v0.8.0 removed.
- A suite that did not run counting as a pass, anywhere. `test-run`
  already holds this (`plugins/bearing/skills/test-run/SKILL.md`, "A suite
  that did not run is never a pass"); nothing here may weaken it.
- A gate that passes on zero items. Every new check fails on empty input
  and prints what it counted.
- Any new file in `plugins/bearing` (see Constraints).

## Constraints

- No em dashes anywhere in prose, comments or commits.
- Every gate fails on zero input and prints the count of what it checked.
- Each `SKILL.md` is at most 200 lines unless `bin/lint-skill-size.allow`
  lists it; none of the skills touched here is listed, and none may be
  added.
- Skills ask with AskUserQuestion as `plugins/bearing/references/console.md`
  says.
- Every command a skill runs is granted in its `allowed-tools`
  (`make lint-tools`).
- Shell is bash 3.2 portable (`make lint-portable`, `tests/ci-bash32.sh`):
  no associative arrays, no `mapfile`, no `${x,,}`.
- Bearing never pushes, merges or tags.
- File budget: `make lint-plugin-size` limits each plugin to under 512
  files; `bearing` holds 508 today. This design adds **zero** files to
  `plugins/bearing`: every change edits an existing file. New tests,
  fixtures and evals live under `tests/` and `evals/`, outside the plugin.
  The count after this branch is still 508.
- Generated files (`docs/WORKFLOW.md`, `docs/SKILLS.md`,
  `site/src/data/handbook.json`, `devguide/src/data/internals.json`,
  `plugins/bearing/bin/flow-steps.tsv`) are regenerated, never edited by
  hand (`make docs`, checked by `make lint-docs`).

## Design

### A. Two test scopes in `test-run`

The user's test types map onto the suites `test-run` already knows
(`plugins/bearing/skills/test-run/references/runners.md`):

| User's word | Layer | Suites (Makefile target) |
| --- | --- | --- |
| unit | `unit` | `test` |
| API | `api` | `test-integration` (Go, Python route and store tests; responses checked against `api/openapi.yaml` where `test-automation` wired it) |
| UI | `ui` | `test-e2e` (Playwright, Maestro), `test-ui` (Android, iOS) |
| visual regression | `visual` | `test-visual` |
| regression | all of the above | the full scope (A3), plus `test-e2e-matrix` at a release (B3) |

**A1. Layers from the diff.** `plugins/bearing/bin/brg-changed` gains a
`--layers` mode (author's call: extend the existing script rather than add
a file). `brg-changed --layers [--base <ref>] [--root <dir>]` lists the
files changed against the merge base of `<ref>` and HEAD plus the working
tree (no `--base`: the working tree only), classifies each, and prints one
`<layer>\t<file>` line per layer a file maps to, then the counts line:

```
brg-changed: <N> files, layers: <unit api ui visual | none>[ (toolchain changed: <file>)]
```

Zero changed files prints `brg-changed: 0 files changed against <base>`
and exits 1. Otherwise it exits 0. Without `--layers` the script behaves
exactly as today (exit 0 always; the hooks rely on it).

Classification, first match wins, on the repository-relative path
(author's call; the builder may add patterns, never remove one):

1. `none`: `*.md`, `docs/*`, `*.txt`, `LICENSE*`, `.gitignore`,
   `.bearing/*`, `.scratch/*`.
2. all four layers (toolchain): `package.json`, `*/package.json`,
   `pnpm-lock.yaml`, `go.mod`, `go.sum`, `pyproject.toml`, `uv.lock`,
   `Makefile`, `*.gradle.kts`, `Package.swift`, `project.yml`,
   `playwright.config.*`, `vitest.config.*`, `jest.config.*`,
   `tsconfig*.json`, `Dockerfile`, `*compose*.yml`, `*compose*.yaml`,
   `.gitlab-ci.yml`, `.github/workflows/*`.
3. test files by folder: `e2e/visual/*` or `*/e2e/visual/*` is `visual`;
   `e2e/*`, `*/e2e/*`, `.maestro/*`, `*/androidTest/*`, `*UITests/*`,
   `integration_test/*` is `ui`; `tests/integration/*`,
   `*/tests/integration/*`, `*_integration_test.go` is `api`; any other
   test file (`*_test.go`, `*.test.*`, `*.spec.*`, `test_*.py`, `*/tests/*`,
   `*Test.kt`, `*Tests.swift`) is `unit`.
4. server source: `api/*`, `*/api/*`, `*/routes/*`, `*/handler/*`,
   `*/handlers/*`, `internal/http/*`, `internal/store/*`, `migrations/*`,
   `*/migrations/*`, `*.sql`, `*/server/*` is `unit` and `api`.
5. UI source: `*.tsx`, `*.jsx`, `*.vue`, `*.svelte`, `*.css`, `*.scss`,
   `*tokens*.json`, `*.dart`, `*/res/layout/*`, `*/ui/*.kt`, `*Screen.kt`,
   `*View.swift`, `*Screen.swift` is `unit`, `ui` and `visual`.
6. anything else is `unit`.

**A2. Scoped run (`test-run --changed`).** The existing `--changed`
selection becomes layer aware:

- It calls `brg-changed --layers --base <base>` with the base it already
  resolves, and runs only the suites of the layers printed. A layer whose
  suite the repository does not have is reported "api: no integration
  suite here" and is not a failure (the suite is absent, not unrun).
- Within a selected suite it selects, as today, test files in the diff,
  test files in the feature folder of a changed source file, and tests
  naming a TC whose case-table row changed. When that selects zero tests
  in a layer the diff touched, it runs that whole suite (author's call: a
  touched layer never runs zero tests). The `visual` layer always runs the
  whole visual suite (author's call: a shared style or token reaches every
  screen, and the suite is small).
- Unit layer reuse (author's call, for speed): when
  `.bearing/state/.check-changed-passed` or `.bearing/state/.check-passed`
  is newer than every changed file, the unit suite is not rerun; the report
  says `unit: covered by make check-changed at <time>` and counts it as
  run with the counts that target printed, when it printed them, else
  `unit: covered, counts n/a`.
- `test-run` gains `Bash(bash *bin/brg-changed*)` in `allowed-tools`.
- Zero layers (a docs-only diff): `0 layers touched by N changed files:
  nothing to test`, exit non-zero, as the empty-selection rule today.
- A scoped run writes its report under `.scratch/test-run/` only, never
  `docs/testing/reports/` (author's call: it is a working check, not an
  archive, and it must not dirty the tree).

**A3. Full run.** Without `--changed`, `test-run` runs every suite present
except `matrix`, `load` and `synthetic` (unchanged). Three argument
changes:

- `--suite` takes a comma list (`--suite e2e,visual`).
- `--suite all` means every present suite except the on-demand ones, so
  `--suite all,matrix` adds the browser and device matrix. When `matrix`
  is selected, `e2e` is dropped, since the matrix runs the same specs on
  chromium too (author's call).
- `--except <suite>[,<suite>]` drops named suites from either scope, so
  `definition-of-done` can skip `unit`, which its `make check` already ran.

A full run writes `docs/testing/reports/<date>-<branch>.md` and `.json` as
today.

**A4. Evidence file and counts line.** Every run, either scope, also
writes `.scratch/test-run/<branch with / as _>-<scope>.json` (scope
`changed` or `full`), overwriting the previous one, with:

```json
{"scope": "changed", "sha": "<HEAD sha>", "dirty": false, "base": "origin/develop",
 "layers": ["unit", "ui", "visual"], "except": [],
 "suites": [{"name": "e2e", "status": "run", "reason": "", "passed": 4, "failed": 0, "skipped": 0}],
 "tests": 9, "failed": 0, "not_run": ["integration"]}
```

`status` is `run`, `covered` (the unit reuse in A2) or `not run`;
`not_run` lists the selected suites that did not run; `tests` and `failed`
count only suites with status `run`. The branch name is
`git branch --show-current` with `/` turned into `_`. The final message
and both report files end with the counts line:

```
test-run: scope <changed|full>, <S> of <P> suites run, <T> tests, <F> failed, <N> not run
```

The autopilot gates read this file (D). `test-heal`'s default input
becomes the newest of `docs/testing/reports/*.json` and
`.scratch/test-run/*.json`, so a scoped failure can be healed.

### B. The flows (`docs/flows.json`)

Insertions are named by step id so they merge with sub-project 2 (F).

**B1. Feature flow.** Today: phases Understand, Plan, Build (`cases`,
`tdd`, `auto`), Verify (`dod`, `review`, the "Anything that needs a deeper
check?" branch with `f-cso` and `f-qa`), Ship. New (author's call on the
phase names and the order):

- Build: unchanged (`cases`, `tdd`, `auto`).
- New phase **Test**: step `testrun` (`test-run`, "Test the change":
  `test-run --changed`, the layers the diff touches); then a branch "Does
  the change need a deeper test?" with options "A user interface"
  (`f-qa`, moved here from Verify) and "A hot path or an endpoint under
  load" (new `f-load`, `load-test` at `smoke` against local or qa,
  optional).
- New phase **Review**: step `review` (`branch-review`, moved from
  Verify); then a branch "Does the change touch auth, payments, personal
  data or external input?" with option "Yes" (`f-cso`, moved here) and
  "No" (no steps).
- Verify: `dod` only, whose `does` now says it runs every suite in full
  (C1).
- Ship: unchanged.

Review comes before definition of done (author's call): review fixes then
fall inside the one full run, and the order matches autopilot's, which is
already `review` then `dod`.

**B2. Bug fix flow.** Flat, no phases (unchanged style). After `green`:
new step `testrun` (`test-run --changed`); then `review`; then the
existing security branch (`cso`); then `dod` (moved after them); then `mr`
and the postmortem branch as today.

**B3. Greenfield flow.** The link step "Build each task with the feature
flow" keeps its target and gains in its title "(each task is tested and
reviewed there)". A new phase **Test and review the release** goes
immediately after that link and before the "First release" phase marker:

- `regression` (`test-run`, "Run the full regression"): every suite plus
  the browser and device matrix (`test-run --suite all,matrix`; "all" is a
  new alias for every present suite). Output: the full report under
  `docs/testing/reports/`.
- `relreview` (`branch-review`, "Review the release as a whole"): the
  range from the previous release tag to HEAD, or from the root commit for
  the first release. It reads across tasks, which the per-task reviews
  cannot.
- a branch "Does the product serve traffic people wait on?" with option
  "Yes": `gf-load` (`load-test`, `load` profile against qa, optional) and
  `gf-resilience` (`resilience-testing drill`, optional); option "No": no
  steps.

The "First release" phase (`scan`, `vapt`, `release`, `runbooks`,
`canary`) is unchanged.

**B4. Inherited flow.** Unchanged: it already runs `test-run` (`suite`,
`baseline`) and links to the feature and bug fix flows, which now carry
both phases (author's call).

**B5. Derived documents.** `bin/gen-guide.py` "Verify" stage rows: the
`test-run` row reads "Run tests: scoped to the change while you work, in
full at definition of done" with output "`.scratch/test-run/` for a scoped
run; `docs/testing/reports/<date>-<branch>.md` and `.json` for a full
run"; the `definition-of-done` row's output gains "every suite run on
HEAD". The `workflow` skill's stage table replaces its one Verify row
with three: Test (`test-run --changed`, `test-heal`, `/qa`, `load-test`),
Review (`branch-review`, `/cso`), Verify (`definition-of-done`, which runs
every suite, `docs-drift`). `make docs` regenerates the rest.

### C. Definition of done and branch-review

**C1. Item 14, suites.** `definition-of-done` gains a fourteenth item,
appended so that "item 13" references elsewhere stay right (author's
call). The list line in Inputs says "fourteen items".

1. Reuse: when `.scratch/test-run/<branch>-full.json` exists with `sha`
   equal to HEAD, `dirty` false and `except` empty or only `unit`, use it;
   no second run.
2. Otherwise run `test-run --except unit` (full scope) with the Skill
   tool; if the Skill tool refuses, read
   `${CLAUDE_PLUGIN_ROOT}/skills/test-run/SKILL.md` and follow it. Before
   it, when the inventory has an integration suite and the Makefile has
   `db` and `migrate` targets, run `make db` and `make migrate`; leave
   nothing running that this item started.
3. Result: `pass` when every selected suite ran and 0 tests failed;
   `n/a: no suite beyond unit (make check ran them)` when unit is the only
   suite; otherwise `fail`, naming each failed test (file:line) or each
   suite not run with its reason.
4. The user's decision (2026-10-18): a suite that cannot run on this
   machine (no device, no simulator on Linux, no Docker) may be left to CI
   only when a CI job in
   `.gitlab-ci.yml` or `.github/workflows/` runs it. Ask once with
   AskUserQuestion: "Leave <suite> to CI job <job>" (recommended) or "I
   will start what it needs and rerun". The accepted answer is recorded in
   the state file as `CI-accepted: <suite> (<job>)` and the row reads
   `pass (<suite> left to CI job <job>, accepted)`. No such job: `fail`,
   no question.

Evidence: the `test-run:` counts line. `allowed-tools` gains the runner
grants the non-unit suites need that it lacks: `Bash(maestro test:*)`,
`Bash(xcodebuild test:*)`, `Bash(./gradlew connectedDebugAndroidTest:*)`,
`Bash(bash *bin/brg-changed*)`.

**C2. Review verdict on disk.** `branch-review` step 7 writes
`.scratch/review/<slug>/verdict.txt` (inside the folder it already owns):

```
review: <range> @ <head sha>, <N> files
Verdict: ready to merge | ready after <items> | not ready to merge
findings: <C> critical, <H> high, <M> medium, <L> low; verified <V>: <c> confirmed, <r> refuted, <u> uncertain
blocking: <finding numbers, space separated, or none>
```

To stay within 200 lines, step 4's "read past the diff" paragraph, which
`references/read-past-the-diff.md` already holds word for word, shrinks to
a two-line pointer. The output contract's "Left behind" line names
`verdict.txt`.

### D. Autopilot

**D1. New stage `test_run`**, immediately after `test_automation` and
before `design_review`. Skill: `test-run --changed`. Gate `g_test_run`:

- reads `.scratch/test-run/<branch>-changed.json`, else `-full.json`;
  neither: `no test-run evidence (.scratch/test-run/<branch>-changed.json; test-run --changed)`;
- fails when no suite has status `run` or `covered` (`0 suites ran`),
  when `failed` > 0, when `sha` is not HEAD (`the run is on <sha>, HEAD is
  <sha>: run test-run again`), when `dirty` is true (`the run was on an
  uncommitted tree: commit, then run again`), and for each suite in
  `not_run` that has no decision with key `test_run.<suite>`
  (`brg-autopilot decision`), naming the suite;
- passes with `<T> tests in <S> suites (<layers>), 0 failed[; left to CI: <suites>]`.

Headless runs cannot start browsers or Docker in every sandbox; the skill
records `decision test_run.<suite> "left to CI job <job>"` for a suite it
cannot start, which the digest lists for the engineer (the user's decision
of 2026-10-18; the recording mechanism is the author's call).

**D2. `g_review` reads the verdict.** The newest
`.scratch/review/*/verdict.txt` by mtime; none: `no .scratch/review/*/verdict.txt (branch-review)`.
Fails when the file count is 0, when the `findings:` line is missing, or
when the reviewed sha is not an ancestor of HEAD. Verdict "not ready to
merge" passes only when every blocking number appears in
`.scratch/review/<slug>/fixed.txt` as `<n> <sha>`, with `<sha>` a commit
after the reviewed one and an ancestor of HEAD; the failure names the
first finding without a fix. Pass line: `review of <N> files: <verdict>; <c> confirmed, <k> fixed`.
Autopilot step 9 appends to `fixed.txt` as it commits each fix.

**D3. `g_dod` reads the full run**, after its existing checks:
`.scratch/test-run/<branch>-full.json` must exist, have 0 `failed`, and a
`sha` from which `git diff --name-only <sha> HEAD` lists only files under
`docs/testing/reports/` (the full report is committed after the run). A
suite in `not_run` needs a `test_run.<suite>` decision, as in D1. The pass
line appends `; full run: <T> tests, 0 failed`.

**D4. Count in the output contract.** The autopilot skill's "Stages: <n>
of 17 done" becomes "Stages: <n> of <N> done", N being the number of lines
`brg-autopilot stages` prints, so the number is never kept by hand again.

### E. Speed, summarised

- In progress: `make check-changed` (unchanged) plus one scoped
  `test-run`, which runs only touched layers, reuses the unit result, and
  writes nothing tracked.
- At done: one full run without unit, reused when HEAD has not moved.
- Review: once; fixes are tied to commits, not re-reviewed.
- Release: the matrix and load runs happen only there.

### F. Merging with sub-project 2

Sub-project 2 (`docs/superpowers/specs/2026-10-17-design-pipeline-design.md`
on `feat/DesignPipeline`) reorders greenfield's design phase, puts the
feature Plan branch's Screens option first, and adds an autopilot
`contract` stage after `ux`. Recommended order: merge sub-project 2 first,
then rebase this branch.

- `docs/flows.json`: this branch edits greenfield only after the link step
  that ends "Plan and build", feature only from the Build phase on, and
  bug fix after `green`. Sub-project 2 edits greenfield's "Decide and
  design the system" phase and feature's Plan phase. No shared hunks.
- `brg-autopilot` `STAGES`: the `test_run` row goes directly after the
  `test_automation` row. `GATES`: write `"test_run": g_test_run,` at the
  start of the line that holds `"design_review": g_design_review`, not on
  the `build` line, so it does not sit next to sub-project 2's `lld` and
  `contract` edit.
- `tests/unit/autopilot_stages.sh` stage-order assertion conflicts for
  certain. Resolved value: `repo branch prd stories decide architecture design repos ux contract lld test_cases build test_automation test_run design_review review dod mr`.
- `autopilot/SKILL.md`: if both branches edited the "Stages:" line, keep
  `<n> of <N>`.
- Generated files conflict for certain; resolve by running `make docs`
  after the merge, never by hand.
- File budget: this branch adds no file to `plugins/bearing`. Sub-project
  2's plan creates about eleven files there (508 plus 11 is over 512); that
  is its problem to solve, and this branch does not make it worse.

## Error handling

- `brg-changed --layers` outside a git repository, or with a `--base` that
  does not resolve: one line on stderr naming it, exit 1.
- `test-run` when `brg-changed` is missing (an older kit): fall back to
  today's `--changed` selection over every suite and say so in the report.
- A malformed evidence or verdict file is a gate failure naming the file
  and the missing field, never a crash (`json.JSONDecodeError`, a missing
  key).

## Testing

- `tests/unit/changed_files.sh`: one case per classification rule, the
  toolchain escalation, zero files (exit 1 with the line), `--base`
  against a branch point, and the unchanged default mode.
- `tests/unit/autopilot_stages.sh`: the stage order; `test_run` failing on
  absent evidence, 0 tests, a failure, a stale sha, and a not-run suite
  without a decision, then passing; `review` failing on no verdict, 0
  files, a blocking finding without a fix, then passing with `fixed.txt`;
  `dod` failing without the full evidence, then passing with only a
  report committed after it.
- Evals: `evals/test-run` gains a scoped case (a CSS-only change selects
  `ui` and `visual`, skips `api`, and reuses the unit result);
  `evals/definition-of-done` gains an item 14 case (an e2e failure fails
  the item although `make check` passes).
- `make check` in this repository passes, including `lint-plugin-size`
  (bearing 508), `lint-skill-size`, `lint-tools`, `lint-docs`,
  `lint-portable`.

## Left to the builder

- Extra classification patterns in A1 for a stack the list misses.
- The exact wording of flow steps' `does`, `output` and `why` lines,
  within B and the RANKING rule in `bin/gen-guide.py`.
- How `test-run` reads the counts `make check-changed` printed, and the
  layout of the scoped report under `.scratch/test-run/`.
- Which lines of `branch-review` move to its reference to make room, as
  long as no rule is lost.
- How item 14 stops a database it started (`docker compose stop
  postgres`, a `db-down` target), as long as nothing it started is left
  running.

## Calls the author made

1. Testing is two scopes of one skill, `test-run`: scoped to the diff in
   the flows, full at definition of done. No new skill.
2. Layers come from a classification inside the existing `brg-changed`
   (zero new plugin files).
3. A touched layer never runs zero tests; visual runs whole.
4. The scoped run reuses a fresh `make check-changed` result for unit.
5. Scoped reports go to `.scratch/`, full reports to `docs/testing/reports/`.
6. Feature flow gains phases named Test and Review; `f-qa` and `f-cso`
   move into them; review precedes definition of done in feature and bug
   fix flows.
7. Greenfield gains a "Test and review the release" phase: full
   regression with the matrix, a whole-release review, optional load and
   resilience.
8. Inherited flow unchanged.
9. Definition of done item 14 is appended, skips unit, reuses a run on the
   same HEAD, and lets a suite go to CI only with an existing CI job and an
   explicit answer (the CI hand-off is the user's decision of 2026-10-18).
10. Review writes `verdict.txt`; autopilot does not re-review after fixes
    but needs a fixing commit per blocking finding.
11. Autopilot gets a `test_run` stage after `test_automation`; the stage
    count in its output contract is no longer a literal.
12. Out of scope: re-review, MR quoting the verdict, load tests by default.
