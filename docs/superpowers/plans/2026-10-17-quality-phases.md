# Quality Phases Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give every task flow a testing phase (scoped to the change while working, in full at definition of done) and a code review phase, and make autopilot enforce both from evidence on disk.

**Architecture:** `brg-changed` learns to map a diff to test layers (unit, api, ui, visual); `test-run` uses that for a fast scoped run and writes one evidence JSON per scope; `definition-of-done` gains item 14, the full run; `branch-review` writes a verdict file; `brg-autopilot` gains a `test_run` stage and reads the verdict and the full run in its `review` and `dod` gates; `docs/flows.json` gains the steps and phases, and the generated docs follow.

**Tech Stack:** bash 3.2 (brg-changed, tests), Python 3 stdlib (brg-autopilot, gen-guide), Markdown skills, JSON (flows, evals).

**Spec:** `docs/superpowers/specs/2026-10-17-quality-phases-design.md`

## Global Constraints

- No em dashes in any prose, comment, commit or test string.
- Every gate fails on zero input and prints the count of what it checked.
- Each `SKILL.md` stays at or under 200 lines; `bin/lint-skill-size.allow` gains no entry.
- Zero new files under `plugins/bearing`; `make lint-plugin-size` still prints `bearing 508 files`.
- Questions go through AskUserQuestion as `plugins/bearing/references/console.md` says.
- Every command a skill runs is in its `allowed-tools` (`make lint-tools`).
- bash 3.2 portable: no associative arrays, `mapfile`, `${x,,}` or `[[ =~ ]]` captures.
- Bearing never pushes, merges or tags; commits have no attribution trailer.
- Generated files are regenerated with `make docs`, never hand-edited.
- Exact strings: `brg-changed: <N> files, layers: <list|none>[ (toolchain changed: <file>)]`; `brg-changed: 0 files changed against <base>`; `test-run: scope <changed|full>, <S> of <P> suites run, <T> tests, <F> failed, <N> not run`; evidence file `.scratch/test-run/<branch with / as _>-<changed|full>.json`; verdict file `.scratch/review/<slug>/verdict.txt`; fix list `.scratch/review/<slug>/fixed.txt`.
- New autopilot stage order: `repo branch prd stories decide architecture design repos ux lld test_cases build test_automation test_run design_review review dod mr`.

## Review Focus

1. A branch whose base cannot be resolved, or a shallow clone with no merge base: `brg-changed --layers --base` must exit 1 with one line naming the base, not list the whole tree as changed. Test in Task 1.
2. File names with spaces in the diff: the layer lines must carry the full name (the existing mode already survives them). Test in Task 1.
3. An evidence or verdict file that is truncated or not JSON (a run killed mid-write): the gate names the file and fails; it never raises. Tests in Task 5.
4. A verdict with `blocking: none` but `Verdict: not ready to merge` (a merge rule broken, no finding): the gate fails naming the verdict, since there is nothing to tie a fix to. Test in Task 5.
5. The full report committed after the DoD run: `g_dod` must accept a HEAD whose only changes since the evidence sha are under `docs/testing/reports/`, and refuse one that also changed code. Tests in Task 5.

---

## File Structure

| File | Responsibility |
| --- | --- |
| `plugins/bearing/bin/brg-changed` (modify) | `--layers` and `--base`: diff to layer lines and the counts line |
| `tests/unit/changed_files.sh` (modify) | classification, toolchain, zero files, base, default mode unchanged |
| `plugins/bearing/skills/test-run/SKILL.md` (modify) | scoped and full scopes, comma `--suite`, `all`, `--except`, evidence file, counts line |
| `plugins/bearing/skills/test-run/references/runners.md` (modify) | layer to suite table, unit reuse rule, selection inside a layer |
| `plugins/bearing/skills/test-run/templates/report.md` (modify) | Scope field and the counts line |
| `plugins/bearing/skills/test-heal/SKILL.md` (modify) | default input includes `.scratch/test-run/*.json` |
| `plugins/bearing/skills/definition-of-done/SKILL.md` (modify) | item 14, suites; fourteen items; grants |
| `plugins/bearing/skills/branch-review/SKILL.md` (modify) | writes `verdict.txt`; step 4 paragraph shrinks to a pointer |
| `plugins/bearing/bin/brg-autopilot` (modify) | `test_run` stage and gate; `g_review` reads the verdict; `g_dod` reads the full run |
| `plugins/bearing/skills/autopilot/SKILL.md`, `references/build-and-after.md`, `references/review-smoke-and-mr.md` (modify) | the stage in the loop, `fixed.txt`, stage count |
| `tests/unit/autopilot_stages.sh` (modify) | order, `test_run`, `review`, `dod` gate cases |
| `docs/flows.json` (modify) | feature Test and Review phases, bug fix order, greenfield release phase |
| `bin/gen-guide.py` (modify) | Verify rows for test-run and definition-of-done |
| `plugins/bearing/skills/workflow/SKILL.md` (modify) | Test, Review, Verify rows |
| `evals/test-run/evals.json`, `evals/test-run/files/css-change/` (modify, create) | scoped-run eval |
| `evals/definition-of-done/evals.json`, `evals/definition-of-done/files/e2e-red/` (modify, create) | item 14 eval |
| generated: `docs/WORKFLOW.md`, `docs/SKILLS.md`, `site/src/data/handbook.json`, `devguide/src/data/internals.json`, `plugins/bearing/bin/flow-steps.tsv` | `make docs` |

---

### Task 1: `brg-changed --layers`

**Files:**
- Modify: `plugins/bearing/bin/brg-changed`
- Test: `tests/unit/changed_files.sh`

**Interfaces:**
- Produces: CLI `brg-changed --layers [--base <ref>] [--root <dir>]`. Stdout: zero or more `<layer>\t<file>` lines (layer one of `unit`, `api`, `ui`, `visual`, `none`), one per layer a file maps to, then the counts line. Exit 1 on zero files or an unresolvable base; else 0. Without `--layers`: today's output and exit 0, unchanged.
- Classification rules and their order: spec A1, verbatim.

- [ ] **Step 1: Write the failing tests** (append to `tests/unit/changed_files.sh`, reusing its `repo` setup)

```bash
L() { bash "$CHANGED" --layers --root "$repo" "$@"; }
t_begin "layers: each rule maps a file to its layers"
# fresh repo r2 with one commit on main, then branch feat with:
#   src/money.ts, internal/http/orders.go, src/components/Button.tsx,
#   e2e/visual/home.spec.ts, e2e/login.spec.ts, tests/integration/test_orders.py,
#   docs/notes.md, "src/my file.go"
assert_exit 0 L --base main            # (run against r2)
assert_contains "$T_OUT" "unit	src/money.ts"
assert_contains "$T_OUT" "api	internal/http/orders.go"
assert_contains "$T_OUT" "unit	internal/http/orders.go"
assert_contains "$T_OUT" "visual	src/components/Button.tsx"
assert_contains "$T_OUT" "ui	src/components/Button.tsx"
assert_contains "$T_OUT" "visual	e2e/visual/home.spec.ts"
assert_contains "$T_OUT" "ui	e2e/login.spec.ts"
assert_contains "$T_OUT" "api	tests/integration/test_orders.py"
assert_contains "$T_OUT" "none	docs/notes.md"
assert_contains "$T_OUT" "unit	src/my file.go"
assert_contains "$T_OUT" "brg-changed: 8 files, layers: unit api ui visual"
t_end
t_begin "layers: a toolchain file selects every layer and says so"
# only package.json changed
assert_contains "$T_OUT" "brg-changed: 1 files, layers: unit api ui visual (toolchain changed: package.json)"
t_end
t_begin "layers: docs only prints none"
# only README.md changed -> exit 0, "brg-changed: 1 files, layers: none"
t_end
t_begin "layers: zero files fails and says against what"
assert_exit 1 L --base main            # clean branch equal to main
assert_contains "$T_OUT" "brg-changed: 0 files changed against main"
t_end
t_begin "layers: an unknown base fails with one line"
assert_exit 1 L --base nosuch
assert_contains "$T_OUT" "nosuch"
t_end
t_begin "layers: base diff excludes commits that landed on the base after the branch point"
# commit x.go on main after branching; it must not appear
assert_not_contains "$T_OUT" "x.go"
t_end
t_begin "default mode is unchanged by the new flags"
assert_exit 0 bash "$CHANGED" --root "$repo"
assert_not_contains "$T_OUT" "brg-changed:"
t_end
```

- [ ] **Step 2: Run to verify they fail**

Run: `bash tests/unit/changed_files.sh`
Expected: FAIL lines for every `layers:` case; the existing cases still pass.

- [ ] **Step 3: Implement `--layers` and `--base` in `brg-changed`**

Parse two more flags. With `--base`: `mb=$(git -C "$root" merge-base "$base" HEAD)` (failure: `brg-changed: base <base> does not resolve` on stderr, exit 1), files are `git diff --name-only -z "$mb"` plus today's porcelain list, sorted unique. A `classify()` function with one `case` per rule group from spec A1 prints the layer lines; accumulate seen layers in a space-separated string, keep the first toolchain file name. Print the counts line in the fixed order `unit api ui visual`.

- [ ] **Step 4: Run to verify they pass**

Run: `bash tests/unit/changed_files.sh && make lint-shell lint-portable && bash tests/ci-bash32.sh`
Expected: `changed_files.sh: ... 0 failed`; lint lines pass; bash32 job passes.

- [ ] **Step 5: Commit**

```bash
git add plugins/bearing/bin/brg-changed tests/unit/changed_files.sh
git commit -m "feat(brg-changed): map a diff to test layers for scoped runs"
```

---

### Task 2: `test-run` scoped and full scopes

**Files:**
- Modify: `plugins/bearing/skills/test-run/SKILL.md`, `references/runners.md`, `templates/report.md`
- Modify: `plugins/bearing/skills/test-heal/SKILL.md` (Inputs, default report)
- Modify: `evals/test-run/evals.json`; Create: `evals/test-run/files/css-change/`

**Interfaces:**
- Consumes: `brg-changed --layers --base <ref>` (Task 1).
- Produces: argument hint `[--suite <s>[,<s>] | all[,matrix]] [--except <s>[,<s>]] [--tag @P1] [--tc TC-0231] [--changed] [--timeout 20m]`; evidence file `.scratch/test-run/<branch>-<scope>.json` with keys `scope, sha, dirty, base, layers, except, suites[{name,status,reason,passed,failed,skipped}], tests, failed, not_run` (spec A4); counts line (Global Constraints). Tasks 3 and 5 read these.

- [ ] **Step 1: Write the failing eval** in `evals/test-run/evals.json`

Case `css-only-change-scoped`: fixture `files/css-change` is a React repo (copy the shape of `files/coupon-branch`: Makefile with `test`, `test-e2e`, `test-visual`; one vitest test, one Playwright spec, one `e2e/visual/` spec) on branch `feat/TASK-7-theme` whose only change against `develop` is `src/styles/theme.css`, and whose `.bearing/state/.check-changed-passed` is newer than it. Prompt: "Run the tests for my change." Expectations: the run prints the `brg-changed:` line with layers `unit ui visual`; it does not run vitest again and says `unit: covered by make check-changed`; it runs the e2e and the whole visual suite; it writes nothing under `docs/testing/reports/`; it writes `.scratch/test-run/feat_TASK-7-theme-changed.json`; the final message ends with a `test-run: scope changed, ...` line.

- [ ] **Step 2: Verify the eval is well formed and currently unmet**

Run: `make lint-evals`
Expected: passes (the case parses). The behaviour is unmet until Step 3; the eval run (`bin/skill-evals.py test-run`, if the session runs evals) fails its expectations.

- [ ] **Step 3: Edit the skill**

`SKILL.md`: argument hint as in Interfaces; Inputs "Selection" names comma lists, `all`, `matrix` replacing `e2e`, `--except`; step 2's `--changed` bullet calls `bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-changed" --layers --base <base>`, runs only the printed layers' suites, and points to `references/runners.md` for the per-layer selection and unit reuse; step 8 says a scoped run writes only under `.scratch/test-run/`, every run writes the evidence file, and the message ends with the counts line; output contract gains `Scope:` and `Layers:` lines and the counts line. `allowed-tools` gains `Bash(bash *bin/brg-changed*)`. Move detail to `runners.md` to stay at or under 200 lines (it is 171 now).
`runners.md`: new section "Layers and scoped selection" with the spec A table (layer to suite), the inside-a-layer selection with the whole-suite fallback, visual always whole, the unit reuse rule with `.check-changed-passed`/`.check-passed`, the fallback when `brg-changed` lacks `--layers` (spec Error handling).
`templates/report.md`: `Scope: changed (layers ...) | full (except ...)` in the header line; the counts line under Summary.
`test-heal/SKILL.md`: the default report is the newest of `docs/testing/reports/*.json` and `.scratch/test-run/*.json`.

- [ ] **Step 4: Verify**

Run: `make lint-skills lint-skill-size lint-tools lint-questions lint-evals lint-prose`
Expected: each prints its counts line and passes; `lint-skill-size` shows test-run at or under 200.

- [ ] **Step 5: Commit**

```bash
git add plugins/bearing/skills/test-run plugins/bearing/skills/test-heal/SKILL.md evals/test-run
git commit -m "feat(test-run): scoped run by layer, full run with --except, evidence per scope"
```

---

### Task 3: Definition of done item 14, suites

**Files:**
- Modify: `plugins/bearing/skills/definition-of-done/SKILL.md`
- Modify: `evals/definition-of-done/evals.json`; Create: `evals/definition-of-done/files/e2e-red/`

**Interfaces:**
- Consumes: `test-run --except unit`, the evidence file and counts line (Task 2).
- Produces: table row `| 14 | suites | pass / fail / n/a | <test-run: line> |`; state-file line `CI-accepted: <suite> (<job>)`.

- [ ] **Step 1: Write the failing eval**

Case `e2e-red-while-check-green`: fixture `files/e2e-red` is a React repo on `feature/TASK-9-filter` whose `make check` passes and whose Playwright spec `e2e/filter.spec.ts` (TC-0040) fails against the change; `.gitlab-ci.yml` has an `e2e` job. Expectations: item 1 passes; item 14 runs `test-run --except unit`, fails naming `e2e/filter.spec.ts` with its line and message; the verdict is `not done`; no question offers to leave e2e to CI, because e2e ran and failed rather than not running.

- [ ] **Step 2: Verify the eval parses**

Run: `make lint-evals`
Expected: passes.

- [ ] **Step 3: Edit the skill**

Inputs: "the fourteen items". Step 3 gains item 14 exactly as spec C1 points 1 to 4 (reuse, run with `make db`/`make migrate` when needed, result rules, CI acceptance with AskUserQuestion and the `CI-accepted:` state line). `allowed-tools` gains `Bash(maestro test:*)`, `Bash(xcodebuild test:*)`, `Bash(./gradlew connectedDebugAndroidTest:*)`, `Bash(bash *bin/brg-changed*)`. Stay at or under 200 lines (174 now).

- [ ] **Step 4: Verify**

Run: `make lint-skills lint-skill-size lint-tools lint-questions lint-evals lint-prose`
Expected: all pass with counts.

- [ ] **Step 5: Commit**

```bash
git add plugins/bearing/skills/definition-of-done/SKILL.md evals/definition-of-done
git commit -m "feat(definition-of-done): item 14 runs every suite in full on HEAD"
```

---

### Task 4: `branch-review` writes its verdict

**Files:**
- Modify: `plugins/bearing/skills/branch-review/SKILL.md`

**Interfaces:**
- Produces: `.scratch/review/<slug>/verdict.txt`, four lines exactly as spec C2 (`review: <range> @ <sha>, <N> files`; `Verdict: ...`; `findings: ...`; `blocking: <numbers|none>`). Task 5 parses it.

- [ ] **Step 1: Make room**

Replace step 4's paragraph starting "Then read past the diff yourself" through "A finding from this pass goes to step 5 like any other." with: "Then read past the diff yourself: every table, column, function, setting and external call the change touches, as references/read-past-the-diff.md lists; a finding from it goes to step 5." Confirm the reference holds every rule removed (it does today, word for word).

- [ ] **Step 2: Add the verdict file**

Step 7 ends: "Write `.scratch/review/<slug>/verdict.txt`:" followed by the four-line block from spec C2. Output contract "Left behind" reads `.scratch/review/<slug>/ (notes and verdict.txt)`.

- [ ] **Step 3: Verify**

Run: `make lint-skills lint-skill-size lint-tools lint-prose`
Expected: pass; branch-review under 200 lines.

- [ ] **Step 4: Commit**

```bash
git add plugins/bearing/skills/branch-review/SKILL.md
git commit -m "feat(branch-review): write the verdict to verdict.txt for gates to read"
```

---

### Task 5: Autopilot `test_run` stage, review and dod gates

**Files:**
- Modify: `plugins/bearing/bin/brg-autopilot` (STAGES, `g_test_run`, `g_review`, `g_dod`, GATES)
- Modify: `plugins/bearing/skills/autopilot/SKILL.md`, `references/build-and-after.md`, `references/review-smoke-and-mr.md`
- Test: `tests/unit/autopilot_stages.sh`

**Interfaces:**
- Consumes: evidence file (Task 2), `verdict.txt` (Task 4).
- Produces: `evidence(d: str, scope: str) -> tuple[dict | None, str]` (the parsed file or None with a reason naming the file); `g_test_run(d: str, st: dict) -> tuple[bool, str]`; `not_run_undecided(st: dict, ev: dict) -> list[str]`; `newest_verdict(d: str) -> tuple[dict | None, str]` with keys `range, sha, files, verdict, findings, blocking: list[int], slug`; `g_review` and `g_dod` keep their signatures.
- STAGES row: `("test_run", "test-run --changed", "a .scratch/test-run/<branch>-changed.json for HEAD with at least one suite run, 0 failed, and every suite not run left to CI by a recorded decision")`, placed directly after the `test_automation` row. GATES: put `"test_run": g_test_run,` at the start of the line holding `"design_review": g_design_review` (spec F).

- [ ] **Step 1: Write the failing tests** in `tests/unit/autopilot_stages.sh`

Helpers: `ev <scope> <json-overrides>` writes `.scratch/test-run/<branch>-<scope>.json` with `sha` = HEAD, `dirty` false, one e2e suite run, `tests` 4, `failed` 0, then applies overrides; `verdict <slug> <verdict> <blocking>` writes the four-line file with the current HEAD sha and 3 files.

```bash
assert_eq "repo branch prd stories decide architecture design repos ux lld test_cases build test_automation test_run design_review review dod mr" "..." "stage order"

t_begin "test_run needs evidence for HEAD with a suite run and nothing failed"
at test_run; profile yes no no no; git -C "$d" switch -qc feat/x
assert_exit 1 ap done test_run;  assert_contains "$T_OUT" "no test-run evidence (.scratch/test-run/feat_x-changed.json"
ev changed '{"suites": [], "tests": 0}'; assert_exit 1 ap done test_run; assert_contains "$T_OUT" "0 suites ran"
ev changed '{"failed": 1}';            assert_exit 1 ap done test_run; assert_contains "$T_OUT" "1 failed"
ev changed '{"sha": "0000000"}';       assert_exit 1 ap done test_run; assert_contains "$T_OUT" "run test-run again"
ev changed '{"dirty": true}';          assert_exit 1 ap done test_run; assert_contains "$T_OUT" "uncommitted tree"
ev changed '{"not_run": ["integration"]}'; assert_exit 1 ap done test_run; assert_contains "$T_OUT" "integration"
ap decision test_run.integration "left to CI job test-integration" "start Docker and rerun" "no Docker in the sandbox" >/dev/null
assert_exit 0 ap done test_run; assert_contains "$T_OUT" "4 tests in 1 suites"; assert_contains "$T_OUT" "left to CI: integration"
printf '{"scope":' > "$d/.scratch/test-run/feat_x-changed.json"
assert_exit 1 ap done test_run; assert_contains "$T_OUT" "feat_x-changed.json"   # Review Focus 3
t_end

t_begin "a unit suite covered by check-changed counts as run"
ev changed '{"suites": [{"name": "unit", "status": "covered", "reason": "", "passed": 0, "failed": 0, "skipped": 0}], "tests": 0}'
assert_exit 0 ap done test_run
t_end

t_begin "review reads the verdict and ties each blocking finding to a fix"
at review; git -C "$d" switch -qc feat/x
mkdir -p "$d/.scratch/review/empty"; assert_exit 1 ap done review; assert_contains "$T_OUT" "no .scratch/review/*/verdict.txt (branch-review)"
verdict r1 "not ready to merge" "1 3"; assert_exit 1 ap done review; assert_contains "$T_OUT" "finding 1"
echo fix > "$d/f.txt"; commit fix; printf '1 %s\n3 %s\n' "$(git -C "$d" rev-parse HEAD)" "$(git -C "$d" rev-parse HEAD)" > "$d/.scratch/review/r1/fixed.txt"
assert_exit 0 ap done review; assert_contains "$T_OUT" "2 fixed"
verdict r2 "not ready to merge" "none"; assert_exit 1 ap done review          # Review Focus 4
verdict r3 "ready to merge" "none"; sed -i.bak 's/, 3 files/, 0 files/' "$d/.scratch/review/r3/verdict.txt"
assert_exit 1 ap done review; assert_contains "$T_OUT" "0 files"
t_end

t_begin "dod needs the full run; only a committed report may follow it"
at dod; profile no no no no; git -C "$d" switch -qc feat/x; echo a > "$d/a.go"; commit a; ( cd "$d" && make -s check )
assert_exit 1 ap done dod; assert_contains "$T_OUT" "feat_x-full.json"
ev full '{"except": ["unit"]}'
mkdir -p "$d/docs/testing/reports"; echo r > "$d/docs/testing/reports/r.md"; commit report; ( cd "$d" && make -s check )
assert_exit 0 ap done dod; assert_contains "$T_OUT" "full run: 4 tests, 0 failed"     # Review Focus 5
echo b > "$d/b.go"; commit code; ( cd "$d" && make -s check )
assert_exit 1 ap done dod; assert_contains "$T_OUT" "b.go"
t_end
```

- [ ] **Step 2: Run to verify they fail**

Run: `bash tests/unit/autopilot_stages.sh`
Expected: FAIL on the stage order and every new case; the existing cases pass.

- [ ] **Step 3: Implement in `brg-autopilot`**

`evidence` reads `.scratch/test-run/<branch>-<scope>.json`, branch from `git branch --show-current` with `/` as `_`; `json.JSONDecodeError`, `OSError` and a missing key become `(None, "<rel>: <what is wrong>")`. `g_test_run` applies spec D1 in the order of the tests above; pass line `<T> tests in <S> suites (<layers>), 0 failed[; left to CI: <suites>]`. `not_run_undecided` returns suites in `not_run` with no `decisions[].key == "test_run.<suite>"`. `newest_verdict` parses the four lines with regexes; `g_review` applies spec D2 (ancestry with `git merge-base --is-ancestor`; `blocking: none` with "not ready" fails as "not ready to merge with no blocking finding to fix"). `g_dod`, after the smoke check, applies spec D3 with `git diff --name-only <sha> HEAD` and the `not_run_undecided` rule.

- [ ] **Step 4: Edit the autopilot skill and references**

`SKILL.md` step 8 adds "then `test-run --changed` (the test_run stage)"; step 9 adds "record each fix as `<n> <sha>` in `.scratch/review/<slug>/fixed.txt`"; output contract "Stages: <n> of <N> done". `build-and-after.md`: a paragraph for the test_run stage (scoped run after test-automation; a suite the sandbox cannot start gets `decision test_run.<suite> "left to CI job <job>"`). `review-smoke-and-mr.md`: `fixed.txt`, no re-review, and that dod's item 14 report is committed before `done dod`.

- [ ] **Step 5: Run to verify they pass**

Run: `bash tests/unit/autopilot_stages.sh && bash tests/unit/autopilot_state.sh && bash tests/unit/autopilot_smoke.sh && make lint-skill-size lint-prose`
Expected: each `... 0 failed`; lints pass.

- [ ] **Step 6: Commit**

```bash
git add plugins/bearing/bin/brg-autopilot plugins/bearing/skills/autopilot tests/unit/autopilot_stages.sh
git commit -m "feat(autopilot): test_run stage; review and dod gates read the verdict and the full run"
```

---

### Task 6: Flows, handbook and the gate

**Files:**
- Modify: `docs/flows.json`, `bin/gen-guide.py` (Verify rows), `plugins/bearing/skills/workflow/SKILL.md` (stage table)
- Regenerate: `docs/WORKFLOW.md`, `docs/SKILLS.md`, `site/src/data/handbook.json`, `devguide/src/data/internals.json`, `plugins/bearing/bin/flow-steps.tsv`
- Test: `tests/unit/session_resume.sh` (existing, must still pass)

**Interfaces:**
- Consumes: the skills' new behaviour (Tasks 2 to 4) for the `does` lines.
- Produces: step ids feature `testrun`, `f-load`; bug fix `testrun`; greenfield `regression`, `relreview`, `gf-load`, `gf-resilience`; feature phases `Test` and `Review`; greenfield phase `Test and review the release`.

- [ ] **Step 1: Edit `docs/flows.json`** exactly as spec B1, B2 and B3, every new step with `id`, `title`, `skill`, `pack`, `does`, `output`, `why`; `f-load`, `gf-load` and `gf-resilience` carry `"optional": true`. Feature: move `review` and the security branch (now "Does the change touch auth, payments, personal data or external input?", options "Yes" with `f-cso`, "No" empty) into Review; `f-qa` into Test's branch. Bug fix: order `green`, `testrun`, `review`, security branch, `dod`, `mr`, postmortem branch. Greenfield: new phase immediately after the `link` to `feature`, before the "First release" phase; the link's title gains "(each task is tested and reviewed there)".

- [ ] **Step 2: Edit `bin/gen-guide.py` and the workflow table** as spec B5.

- [ ] **Step 3: Regenerate and check**

Run: `make docs && make lint-docs && bash tests/unit/session_resume.sh && bash tests/unit/gen_wiki.sh`
Expected: `site data: ... flows (<n> steps)` with no problems; `lint-docs: 5 generated docs up to date`; tests `0 failed`. In `plugins/bearing/bin/flow-steps.tsv`, feature reads `test-automation`, `test-run`, `qa`, `load-test`, `branch-review`, `cso`, `definition-of-done`, `merge-request`.

- [ ] **Step 4: Run the whole gate**

Run: `make check`
Expected: `check: passed`; `lint-plugin-size:` shows `bearing 508 files`; `lint-skill-size:` lists no new entry over 200.

- [ ] **Step 5: Commit**

```bash
git add docs/flows.json bin/gen-guide.py plugins/bearing/skills/workflow/SKILL.md docs/WORKFLOW.md docs/SKILLS.md site/src/data/handbook.json devguide/src/data/internals.json plugins/bearing/bin/flow-steps.tsv
git commit -m "feat(flows): test and review phases in every flow; full regression before release"
```

---

## Self-review

1. **Spec coverage.** A1: Task 1. A2 to A4 and test-heal: Task 2. B1 to B5: Task 6. C1: Task 3. C2: Task 4. D1 to D4: Task 5. E is a summary of the above. F: GATES placement and stage order in Task 5; generated files in Task 6; the merge order is the engineer's. Error handling: unknown base (Task 1), malformed files (Task 5), missing `--layers` fallback (Task 2 `runners.md`). Testing section: Tasks 1, 2, 3, 5, 6.
2. **Step scan.** Every code step names the file, the function and the values; the skill edits name the section and the spec paragraph that fixes their content.
3. **Type consistency.** Evidence keys match between Task 2 Interfaces, Task 5 helpers and spec A4; `verdict.txt` lines match between Task 4 and `newest_verdict`; stage name `test_run` and decision key `test_run.<suite>` are the same everywhere.
4. **Review Focus.** Five lines, each with its test in Task 1 or Task 5.
5. **Proportion.** Six tasks against a spec of six design sections; code blocks are tests and exact strings only.

Merging with sub-project 2: after `feat/DesignPipeline` lands, rebase this branch; the stage-order assertion becomes `repo branch prd stories decide architecture design repos ux contract lld test_cases build test_automation test_run design_review review dod mr`, and `make docs` resolves every generated file.
