# Design Pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hand visual judgement to impeccable while Bearing keeps its artifacts and gates, give every primary task a counted path checked against a budget, and derive the API contract and data model from the screens' data needs.

**Architecture:** Impeccable is pinned and installed like gstack (standard and full profiles); one shared reference (`plugins/bearing/references/impeccable.md`) tells the four design skills how to detect it, invoke it, and which of its commands may run unattended. Three new checks carry the measurable parts: a `## Task paths` parser and budget in `flows_check.py`, `data_needs_check.py` in screen-design (shared parser reused by `openapi-spec/scripts/needs_check.py` and `model_check.py --needs`), and a POSIX `design-sync.sh` that ties `tokens.json` to the `DESIGN.md` hash. The flows and autopilot are reordered so screens precede the contract.

**Tech Stack:** Python 3 standard library for checks (PyYAML optional through `uv`, JSON fallback), POSIX sh and awk for the repo-installed check, bash 3.2 tests on `tests/lib/assert.sh`, Make, JSON for flows and evals.

**Spec:** `docs/superpowers/specs/2026-10-17-design-pipeline-design.md` (sections A to D binding; D overrides A where they differ).

## Global Constraints

- No em dashes anywhere: prose, commits, docs, comments, YAML and CSV cells (`make lint-prose`).
- Commits: Conventional Commits, no attribution trailer, no "generated with" line.
- Every new gate or check fails on zero input and prints the count it checked; a check that examined zero items did not pass.
- SKILL.md at most 200 lines, or within its row in `bin/lint-skill-size.allow` (`make lint-skill-size`). ux-flows (198), design-directions (200), design-system (200), design-critique (199) and data-model (200) are at the limit: every task that adds lines to one moves detail to `references/` in the same task.
- Skills ask with AskUserQuestion as `plugins/bearing/references/console.md` says (`make lint-questions`).
- Every command a skill or its references run is granted in its `allowed-tools` (`make lint-tools`); no backticked code span wrapped across lines.
- Bash scripts are bash 3.2 and BSD portable: `make lint-portable` rejects `sed -i` without a suffix, `perl`, `grep -P`, `readlink -f`, `date -d`; a `case` pattern inside `$(...)` is parenthesised. The repo-installed `design-sync.sh` is POSIX sh and awk only.
- Every external fetch is pinned in `plugins/bearing/bin/pinned-packs.txt` (`tests/unit/pins_match.sh`).
- Markdown templates open with a guidance comment and every `##` or `###` section carries a `What:` and a `Good:` line (`make lint-templates`).
- After any change to a skill, `docs/flows.json` or `bin/gen-guide.py`: run `make docs` and commit the regenerated files; never hand-edit `docs/SKILLS.md`, `docs/WORKFLOW.md`, `site/src/data/handbook.json`, `devguide/src/data/internals.json`, `plugins/bearing/bin/flow-steps.tsv`.
- Tests source `tests/lib/assert.sh`, run make through its `mk` helper, and are `chmod +x` (an unexecutable test file fails `tests/run.sh`).
- Bearing never pushes, tags or deploys.
- Bearing must still work without impeccable: each skill prints `impeccable not installed` once and falls back to today's behaviour.
- Unattended means `--unattended`, or `BEARING_AUTOPILOT` set and not `0`, or `BEARING_NONINTERACTIVE=1` (the rule `brg-guard` and `brg-session` already use). Unattended, no impeccable command that asks may run.
- Budget defaults, verbatim from the spec: a primary task at most 3 screens and 6 interactions from entry to success; a secondary task at most 5 screens and 10 interactions. Keys: `ux.budget.primary.screens`, `ux.budget.primary.interactions`, `ux.budget.secondary.screens`, `ux.budget.secondary.interactions` in `.bearing/config.json` (flat keys, string values, as `brg-config set` writes them).
- Exact output lines from the spec: `task paths: N tasks, M over budget (K with reason)`; `data needs: N actions, M mapped, K new operations` (later fields follow after `; `).
- `make check` must end with `check: passed`.

## Review Focus

1. A flows file written before this change (no `## Task paths` section) now fails `flows_check.py`; the problem line must say what to add and where the rule lives, not just "0 task paths". Pinned in Task 2.
2. A `.bearing/config.json` budget written by `brg-config set` holds strings (`"4"`): it must count as 4, and a non-number (`"four"`, `"0"`) must be a named problem, not a crash or a silent default. Pinned in Task 2.
3. Impeccable installed but the run unattended (autopilot sets `BEARING_AUTOPILOT=1`): design-directions must not start `init` or `document --seed`, and design-critique must not run `critique` (it asks at its close). Pinned in Task 12 (eval case) and stated in the Task 4 shared reference.
4. A repository from before this change whose root `DESIGN.md` is Bearing's symlink to `docs/design/DESIGN.md`: impeccable would write through it into Bearing's guide. design-directions removes the symlink before seeding; `design-sync.sh` hashes the file a symlink points to. Pinned in Task 5.
5. Two features whose data-needs files both use `A-01`: `x-data-needs: [A-01]` becomes ambiguous; `needs_check.py` must fail naming both files. Pinned in Task 8.

---

## File Structure

| File | Responsibility |
|---|---|
| `plugins/bearing/bin/pinned-packs.txt` (modify) | `cli|pbakaus/impeccable|<commit>||impeccable|Apache-2.0` row |
| `install.sh` (modify) | impeccable in standard and full, `--skip-impeccable` |
| `plugins/bearing/bin/brg-doctor` (modify) | reports impeccable and its version; required on standard and full |
| `docs/THIRD_PARTY.md`, `docs/known-skills.txt`, `README.md` (modify) | impeccable listed, its version, the fetch row |
| `plugins/bearing/references/impeccable.md` (create) | detection, invocation, unattended rule, which commands ask, inferred-facts record |
| `plugins/bearing/skills/ux-flows/scripts/flows_check.py` (modify) | `## Task paths` parse, recount, budget, story coverage |
| `plugins/bearing/skills/ux-flows/references/task-paths.md` (create) | table, path syntax, counting rules, budget, `over:` reasons, the six patterns |
| `plugins/bearing/skills/ux-flows/references/batch-and-cost-copy.md` (create) | three long gotchas moved out of SKILL.md |
| `plugins/bearing/skills/ux-flows/templates/flows.md` (modify) | `## Task paths` section |
| `plugins/bearing/skills/design-directions/SKILL.md` and `references/impeccable-round.md` (create) | one impeccable round, `approved.json` from the pick, fallback |
| `plugins/bearing/skills/design-system/templates/design-sync.sh` (create) | POSIX hash check, `--hash` |
| `plugins/bearing/skills/design-system/references/from-impeccable.md` (create) | frontmatter and sidecar to `tokens.json` mapping, symlink reversal |
| `plugins/bearing/skills/design-system/templates/tokens.schema.json` (modify) | `meta.sourceHash`, `meta.sourcePath` |
| `plugins/bearing/skills/screen-design/references/impeccable-pass.md` (create) | harden then polish, the brief, gates after |
| `plugins/bearing/skills/screen-design/scripts/data_needs_check.py` (create) | shared parser and the data-needs gate |
| `plugins/bearing/skills/screen-design/templates/data-needs.md` (create) | the file screen-design writes |
| `plugins/bearing/skills/openapi-spec/scripts/needs_check.py` (create) | coverage of data needs by operations |
| `plugins/bearing/skills/data-model/scripts/model_check.py` (modify) | `--needs` field coverage |
| `plugins/bearing/skills/design-critique/references/review-checklist.md` (modify) | category 12, task cost, counted |
| `docs/flows.json`, `bin/gen-guide.py`, `plugins/bearing/skills/workflow/SKILL.md` (modify) | screens before contract |
| `plugins/bearing/bin/brg-autopilot` (modify) | `contract` stage after `ux`; impeccable pick accepted |
| `tests/unit/{doctor_packs,design_sync,screen_data_needs,api_data_needs,flow_order}.sh` (create) | new tests |
| `tests/fixtures/data-needs/{flows.md,data-needs.md,openapi.json}` (create) | shared fixture for Tasks 7, 8, 11 |
| `evals/{ux-flows,screen-design,openapi-spec,design-directions}/evals.json` (modify) | new cases |
| `CHANGELOG.md` (modify) | Unreleased entries |

---

### Task 1: Pin and install impeccable

**Files:**
- Modify: `plugins/bearing/bin/pinned-packs.txt` (new cli row with a comment line above it)
- Modify: `install.sh` (header comment for standard; option `--skip-impeccable`; block after GSD Core in "third-party packs")
- Modify: `plugins/bearing/bin/brg-doctor:64-78` (profile line, impeccable `pack_check`)
- Modify: `docs/THIRD_PARTY.md` ("Installed by profile" row; "How the design lane uses other packs")
- Modify: `docs/known-skills.txt` (`impeccable`, sorted), `README.md` (fetch table row under `install.sh`, profile standard or full)
- Test: `tests/unit/install_dry_run.sh` (new case), `tests/unit/doctor_packs.sh` (create)

**Interfaces:**
- Produces: the row `cli|pbakaus/impeccable|<40-hex commit>||impeccable|Apache-2.0`; read with `pin cli pbakaus/impeccable` in `install.sh`. Installed copy at `~/.claude/skills/impeccable/SKILL.md` or `~/.agents/skills/impeccable/SKILL.md`; its version is the `  version:` line under `metadata:`.

- [ ] **Step 1: Confirm the pin**

Run: `git ls-remote https://github.com/pbakaus/impeccable HEAD`, then fetch `08d5b470495d242ca0470f4aeae1956c3a074f83` into `.scratch/impeccable` and read `SKILL.md` `metadata.version` and `scripts/VERSION`.
Expected: version 4.5.2 or later. If not, pin the newest commit that is, and read its `SKILL.md` plus `reference/{routing,new-work,init,document,critique,audit,polish,harden}.md` before listing it (the file's rule: every row read at its commit). Record in the row's comment: `# impeccable <metadata version> (scripts/VERSION <x>), read <date>`.

- [ ] **Step 2: Write the failing tests**

In `tests/unit/install_dry_run.sh`:

```bash
t_begin "--dry-run: standard installs impeccable at its pin; minimal and --skip-impeccable do not"
isha="$(awk -F'|' '$1=="cli" && $2=="pbakaus/impeccable" {print $3}' "$pins")"
skv="$(awk -F'|' '$1=="npm" && $2=="skills" {print $3}' "$pins")"
_t_count; printf '%s' "$isha" | grep -Eq '^[0-9a-f]{40}$' || _t_fail "impeccable is not pinned to a full commit: '$isha'"
assert_exit 0 under_fake --dry-run
assert_contains "$T_OUT" "would run  npx --yes skills@$skv add pbakaus/impeccable#$isha -a claude-code -g -y"
assert_exit 0 under_fake --dry-run --profile minimal
assert_not_contains "$T_OUT" "pbakaus/impeccable"
assert_exit 0 under_fake --dry-run --skip-impeccable
assert_contains "$T_OUT" "skipped    impeccable"
t_end
```

Create `tests/unit/doctor_packs.sh` (fake HOME, real `brg-doctor`, as `doctor_trust.sh` does):

```bash
t_begin "standard profile without impeccable is MISSING with the install command"
out="$(cd "$repo" && HOME="$home" BEARING_PROFILE=standard bash "$D" 2>&1)"
assert_contains "$out" "MISSING   impeccable not installed (bash install.sh, or npx --yes skills@"
assert_contains "$out" "add pbakaus/impeccable#"
t_end
t_begin "minimal profile: impeccable is optional"
out="$(cd "$repo" && HOME="$home" BEARING_PROFILE=minimal bash "$D" 2>&1)"
assert_contains "$out" "optional  impeccable not installed"
t_end
t_begin "an installed copy under ~/.claude or ~/.agents reports its version"
mkdir -p "$home/.agents/skills/impeccable"; printf -- '---\nname: impeccable\nmetadata:\n  version: 4.5.2\n---\n' > "$home/.agents/skills/impeccable/SKILL.md"
out="$(cd "$repo" && HOME="$home" BEARING_PROFILE=standard bash "$D" 2>&1)"
assert_contains "$out" "ok        impeccable 4.5.2"
t_end
```

- [ ] **Step 3: Run them to verify they fail**

Run: `bash tests/unit/install_dry_run.sh; bash tests/unit/doctor_packs.sh`
Expected: FAIL on "impeccable is not pinned" and "does not contain [MISSING   impeccable not installed".

- [ ] **Step 4: Add the row and the install, doctor and doc lines**

Row and comment as Step 1. `install.sh`: `skip_impeccable=0`; `--skip-impeccable` in the option loop and the usage line; in the non-minimal branch after GSD Core: present when `~/.claude/skills/impeccable` or `~/.agents/skills/impeccable` exists (`had "impeccable"`), else `runq npx --yes "skills@$(pin npm skills)" add "pbakaus/impeccable#$(pin cli pbakaus/impeccable)" -a claude-code -g -y`, `fail` on an empty pin. Header comment: standard is "minimal plus Superpowers, gstack, GSD Core and impeccable". `brg-doctor`: profile line names impeccable as required; `pack_check "$imp" "impeccable $impv" "impeccable not installed (bash install.sh, or npx --yes skills@<pin> add pbakaus/impeccable#<pin> -a claude-code -g -y)"`. THIRD_PARTY row: `| impeccable (pbakaus) | standard | npx skills@1.7.0 add pbakaus/impeccable#<commit> -a claude-code -g -y | Apache-2.0 | design-directions (init, document --seed), design-system (reads its DESIGN.md), screen-design (polish, harden), design-critique (audit, critique) |`, with the version from Step 1; the design-lane section says impeccable now does direction and visual judgement and `/design-consultation` is an alternative direction source. In full profile `brg-install-packs` reaches the same row and reports it present.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `bash tests/unit/install_dry_run.sh; bash tests/unit/doctor_packs.sh; bash tests/unit/pins_match.sh`
Expected: each prints `<file>: N cases, M assertions, 0 failed`; pins_match's checker line ends `, 0 problems`.

- [ ] **Step 6: Commit**

```bash
chmod +x tests/unit/doctor_packs.sh
git add plugins/bearing/bin/pinned-packs.txt install.sh plugins/bearing/bin/brg-doctor docs/THIRD_PARTY.md docs/known-skills.txt README.md tests/unit/install_dry_run.sh tests/unit/doctor_packs.sh
git commit -m "feat(install): pin impeccable and install it in the standard profile"
```

---

### Task 2: Task paths and budget in flows_check

**Files:**
- Modify: `plugins/bearing/skills/ux-flows/scripts/flows_check.py` (docstring, `check`, `main`, new functions below)
- Test: `tests/unit/ux_flows_check.sh` (fixture gains a Task paths section; new cases)
- Modify: `tests/unit/autopilot_stages.sh` (`flows()` fixture gains a Task paths section so the ux gate still passes)

**Interfaces:**
- Consumes: `inventory_full(text) -> (screens, terminal, dialogs, removed)` and `section(text, title)` in the same file.
- Produces:
  - `count_path(cell: str) -> tuple[int, int, list[str]]`: (distinct screens, interactions, screen ids in order). Syntax: segments split on ` > `; a segment is `S-nn[ (modal)][: item, item, ...]`; each non-empty comma item is one interaction (a typed field is one item, `type email`); a segment with no colon has 0 interactions.
  - `task_paths(text: str) -> list[dict]`: rows of the table under `^##\s+(?:\d+\.\s*)?Task paths`; keys `task`, `story` (list of `US-...` ids), `kind`, `entry`, `path`, `screens` (int written), `interactions` (int written), `over` (text after `over:`, `""` when the cell is blank, `None` when it reads `over:` with nothing after).
  - `budget(config_path: str) -> tuple[dict, list[str]]`: `({"primary": (screens, interactions), "secondary": (...)}, problems)`; defaults `(3, 6)` and `(5, 10)`; a value that is not a whole number above 0 is a problem and the default stays.
  - CLI: `flows_check.py [--file F ...] [--root R] [--config .bearing/config.json]`; prints, after `Dead ends:`, the line `task paths: N tasks, M over budget (K with reason)`. The `ux-flows:` counts line is unchanged.

Table header: `| Task | Story | Kind | Entry | Path | Screens | Interactions | Over |`.

- [ ] **Step 1: Write the failing tests**

Add to `fixture()`, after the inventory:

```bash
printf '## Task paths\n\n| Task | Story | Kind | Entry | Path | Screens | Interactions | Over |\n| --- | --- | --- | --- | --- | --- | --- | --- |\n'
printf '| Confirm an order | US-01-001 | primary | S-01 | S-01: tap Confirm > S-02 (modal): tap Confirm > S-03 | 3 | 2 | |\n\n'
```

New cases (each asserts exit code and the named lines):

```bash
t_begin "task paths within budget pass and print their count"
# fixture as is: exit 0; "task paths: 1 tasks, 0 over budget (0 with reason)"
t_begin "a task over budget fails; over: <reason> passes and is counted; over: alone fails"
# path S-01: tap a, tap b, tap c, tap d > S-02 (modal): tap e, tap f > S-03: tap g, written 3 | 7
# exit 1; 'task "Confirm an order" is over budget: 3 screens, 7 interactions (primary budget 3 and 6)'
# "task paths: 1 tasks, 1 over budget (0 with reason)"
# Over "over: destructive action confirmation" -> exit 0; "1 over budget (1 with reason)"
# Over "over:" -> exit 1; 'task "Confirm an order" over: needs a reason'
t_begin "written counts that disagree with the path fail"
# written 2 | 2 -> 'task "Confirm an order" counts written 2 screens, 2 interactions; the path has 3 and 2'
t_begin "a secondary task gets the secondary budget"
# the 7-interaction path with kind secondary -> exit 0; kind "maybe" -> 'kind must be primary or secondary'
t_begin "a story with no path, a path through an unknown screen, and an entry that is not the first screen fail"
# S-04 row serving US-01-002 -> 'story US-01-002 is served by the inventory but has no task path'
# path through S-09 -> 'task "Confirm an order" path names S-09, not in the inventory'
# Entry S-02 -> 'task "Confirm an order" entry S-02 is not the first screen of its path (S-01)'
t_begin "a package with no Task paths section fails and names the fix"
# section removed -> exit 1; "0 task paths (add a ## Task paths section, one row per primary task: ux-flows references/task-paths.md)"
t_begin "the repository budget in .bearing/config.json applies; strings count, non-numbers are problems"
# {"ux.budget.primary.interactions": "2"} -> path with 2 interactions exit 0; 3 -> "(primary budget 3 and 2)"
# {"ux.budget.primary.screens": "four"} -> '.bearing/config.json: ux.budget.primary.screens is "four", not a whole number above 0'
```

In `autopilot_stages.sh` `flows()`: add `| Finish an order | US-01-001 | primary | S-01 | S-01: tap Done > S-02 | 2 | 1 | |` under the same header.

- [ ] **Step 2: Run them to verify they fail**

Run: `bash tests/unit/ux_flows_check.sh`
Expected: FAIL, "does not contain [task paths: 1 tasks".

- [ ] **Step 3: Implement `count_path`, `task_paths`, `budget` and wire them into `check` and `main`**

`check(path, limits)` gains the task-path problems above and returns `tasks`, `over`, `over_reason`; story coverage reads the `US-` ids in the inventory's Serves column of non-removed rows; when the inventory names no story, at least one row is required. The budget compares recomputed counts, never the written ones. Config problems are reported once per run.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bash tests/unit/ux_flows_check.sh; bash tests/unit/autopilot_stages.sh`
Expected: `ux_flows_check.sh: 17 cases, ... 0 failed` (10 existing plus 7 new) and `autopilot_stages.sh: ... 0 failed`; the existing exact `ux-flows: 1 files, 3 screens ...` line still matches.

- [ ] **Step 5: Commit**

```bash
git add plugins/bearing/skills/ux-flows/scripts/flows_check.py tests/unit/ux_flows_check.sh tests/unit/autopilot_stages.sh
git commit -m "feat(ux-flows): count task paths and hold them to a budget in flows_check"
```

---

### Task 3: ux-flows writes task paths and steers away from inflating patterns

**Files:**
- Modify: `plugins/bearing/skills/ux-flows/SKILL.md` (new step after step 7; output contract; Gotchas; allowed-tools)
- Create: `plugins/bearing/skills/ux-flows/references/task-paths.md`
- Create: `plugins/bearing/skills/ux-flows/references/batch-and-cost-copy.md` (the "Many items in one input", "Costs and counts before sending" and "Work that outlives the screen" gotchas, moved verbatim)
- Modify: `plugins/bearing/skills/ux-flows/templates/flows.md` (`## Task paths` after section 6, with What and Good comment and one example row)
- Modify: `plugins/bearing/skills/ux-flows/references/flow-review.md` (check F14 Task cost, result from the gate)

**Interfaces:**
- Consumes: Task 2's table header, path syntax and output line.
- Produces: `references/task-paths.md`, which Task 9 cites for the six patterns.

- [ ] **Step 1: Write `references/task-paths.md`**

Content: one row per primary task (one per story the flows cover, or per job when there are no stories) and per secondary task (settings, admin); the header and path syntax from Task 2 with one worked example and its counts; budgets 3 screens and 6 interactions (primary), 5 and 10 (secondary), not counting typing the content itself; the four config keys set with `bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-config" set ux.budget.primary.screens <n>`; legitimate `over:` reasons (a legal confirmation, a payment step the provider owns, a destructive or irreversible action's confirmation); a confirmation on a destructive action is kept and counted, never dropped to fit. The six patterns, one line each with what to do instead: confirmation on a reversible action (undo); separate page for a short create or edit form (inline or a sheet); wizard for under five fields (one form); navigating away to pick a related item (inline picker); empty state with no primary action (put the action in it); success page that is a dead end (return to the list with the new item highlighted).

- [ ] **Step 2: Edit SKILL.md, the template and F14**

New step: write `## Task paths` per `references/task-paths.md`; a task over budget is redesigned with the patterns first, `over: <reason>` only for a listed reason. Step 10 names F2, F4 and F14 as gate results. Output contract gains `<flows_check.py "task paths:" line, verbatim>` after the Dead ends line. Gotchas: replace the three moved items with `Batches, totals and queued sends: references/batch-and-cost-copy.md`; add "A budget never removes a destructive action's confirmation; write `over: destructive action confirmation`." allowed-tools gains `Bash(bash *bin/brg-config*)`.

- [ ] **Step 3: Verify**

Run: `make lint-skills lint-skill-size lint-tools lint-questions lint-templates lint-prose`
Expected: each target exits 0; `lint-skill-size` reports no ux-flows line (at or under 200).

- [ ] **Step 4: Commit**

```bash
git add plugins/bearing/skills/ux-flows
git commit -m "feat(ux-flows): task paths section, budget rules and the patterns that inflate paths"
```

---

### Task 4: Shared impeccable reference and one direction round in design-directions

**Files:**
- Create: `plugins/bearing/references/impeccable.md`
- Create: `plugins/bearing/skills/design-directions/references/impeccable-round.md`
- Modify: `plugins/bearing/skills/design-directions/SKILL.md` (Inputs, a "Which path" step, step 10 approved.json, output contract, allowed-tools); step 6 shrinks to a pointer, its text moves into `references/react-shadcn-build.md`

**Interfaces:**
- Produces:
  - `impeccable.md` sections Detect, Invoke, Unattended, Commands, Inferred facts, used by Tasks 5, 6, 9.
  - `approved.json` from the impeccable path: `{"round": 1, "date": "<iso>", "source": "impeccable", "chosen": "<direction name>", "challengers": ["<name>", ...], "recommended": null, "inferred": ["<fact>", ...], "evidence": {"contrast": "<pairs.py counts line>", "screenshots": "<evidence.py check line>"}, "notes": ""}`; the fallback writes today's shape plus `"source": "bearing"`. Task 11's gate reads `source`, `chosen` and `challengers`.
  - Root `DESIGN.md` (impeccable format, YAML frontmatter) and `.impeccable/design.json`, written by impeccable's `document --seed` right after the pick (D3).

Findings from impeccable's references to record in `impeccable.md` (Commands table, columns Command, Bearing skill, Asks?, Unattended):

| Command | Bearing skill | Asks? | Unattended |
|---|---|---|---|
| `init` | design-directions | yes, one answer round before PRODUCT.md (init.md step 3) | not run |
| `document --seed` | design-directions | yes, the world workshop's decision page (document.md seed mode, new-work.md section 2); no second ask when new-work already ran this session | not run |
| `polish` | screen-design | only when a binding principle cannot be inferred or a claim would change (polish.md section 1, copy rule) | run, naming `DESIGN.md` and `docs/design/tokens.json` as the binding system and the flows' copy as fixed |
| `harden` | screen-design | no | run, with the flows' copy as the only copy |
| `audit` | design-critique | no | run |
| `critique` | design-critique | yes, at its close when it lists 3 or more priority issues (critique.md Ask the User) | not run; audit only |

- [ ] **Step 1: Write `plugins/bearing/references/impeccable.md`**

Detect: the `impeccable` skill is listed in this session, else `test -f ~/.claude/skills/impeccable/SKILL.md` or `~/.agents/skills/impeccable/SKILL.md`; absent: print `impeccable not installed` once and use the skill's fallback. Invoke: the Skill tool with skill `impeccable` and the command as its argument (`document --seed S-01`), never the bare `polish`, `audit`, `critique` or `harden` skills (in the full profile those names are ui-craft's). Unattended: `--unattended`, or `printenv BEARING_AUTOPILOT BEARING_NONINTERACTIVE` shows `BEARING_AUTOPILOT` set and not `0` or `BEARING_NONINTERACTIVE=1`. The Commands table above. Inferred facts: every fact impeccable labels inferred goes in the skill's report as `inferred:`. Copy: the flows own copy; a copy change impeccable proposes is listed, not applied. Gates: Bearing's gates run after every impeccable edit; a change that breaks one is reverted.

- [ ] **Step 2: Write `references/impeccable-round.md` and edit SKILL.md**

Attended with impeccable: when root `DESIGN.md` is a symlink (`test -L DESIGN.md`), remove the link (`rm DESIGN.md`; the guide it pointed at stays) and say so; run `init` when `PRODUCT.md` is absent; run `document --seed <first screen of the happy path>` with the flows path, the PRD and the constraints from step 1 as the brief; the pick on impeccable's decision page is recorded in `approved.json` (Interfaces) with the challengers it beat; then Bearing renders the picked direction over the real screens (one `1-<name>` page or theme, steps 6 to 9) and runs pairs.py and evidence.py; the board shows that evidence, never a second choice. Fallback (impeccable absent or unattended): today's three variants, unchanged; unattended with impeccable installed prints `impeccable direction round skipped: unattended (it needs an answer)`. Output contract gains `Path: impeccable (one round; picked <name> over <challengers>) | fallback: three variants (impeccable not installed | unattended)` and `Impeccable: <commands run>; inferred: <facts> | none`. allowed-tools gains `Skill`, `Bash(printenv BEARING_AUTOPILOT BEARING_NONINTERACTIVE)`, `Bash(rm DESIGN.md)`, `Bash(*skills/impeccable/scripts/impeccable *)`. `design-doctrine.md` stays as the fallback's doctrine.

- [ ] **Step 3: Verify**

Run: `make lint-skills lint-skill-size lint-tools lint-questions lint-prose`
Expected: each exits 0; design-directions SKILL.md at or under 200 lines.

- [ ] **Step 4: Commit**

```bash
git add plugins/bearing/references/impeccable.md plugins/bearing/skills/design-directions
git commit -m "feat(design-directions): one impeccable direction round, recorded as the approved direction"
```

---

### Task 5: DESIGN.md as the source, tokens derived and hash-checked

**Files:**
- Create: `plugins/bearing/skills/design-system/templates/design-sync.sh`
- Create: `plugins/bearing/skills/design-system/references/from-impeccable.md`
- Modify: `plugins/bearing/skills/design-system/templates/tokens.schema.json` (`meta.sourceHash` pattern `^sha256:[0-9a-f]{64}$`, `meta.sourcePath` string)
- Modify: `plugins/bearing/skills/design-system/SKILL.md` (Inputs and step 1: root `DESIGN.md` with YAML frontmatter first; step 6 records the hash; step 8 writes no `DESIGN.md` on this path and reverses the symlink; the lint section shrinks to a pointer at `references/lint.md`, which gains the design-sync install)
- Test: `tests/unit/design_sync.sh` (create)

**Interfaces:**
- Consumes: Task 4's root `DESIGN.md` and `.impeccable/design.json`; `impeccable.md` Detect.
- Produces: `sh scripts/design-sync.sh` (check) and `sh scripts/design-sync.sh --hash` (prints `sha256:<64 hex>` of the source); env `DESIGN_SOURCE` (default `DESIGN.md`), `DESIGN_TOKENS` (default `docs/design/tokens.json`). Installed as `scripts/design-sync.sh` with a `design-sync` target under `check` only when the tokens are derived from an impeccable `DESIGN.md`. Output:
  - pass: `design-sync: 1 source checked, DESIGN.md matches tokens.json (sha256:<first 12>)`, exit 0
  - drift: `design-sync: DESIGN.md is sha256:<new>, tokens.json was derived from sha256:<old>; rerun design-system to re-derive the tokens`, exit 1
  - zero input (no source, no tokens file, or no `sourceHash` in it): `design-sync: 0 sources checked (<which is missing>)`, exit 1
  - no hasher: `design-sync: no sha256 tool (sha256sum, shasum or openssl)`, exit 1

- [ ] **Step 1: Write the failing tests**

```bash
t_begin "--hash prints the source's sha256"          # matches ^sha256:[0-9a-f]{64}$
t_begin "tokens derived from this DESIGN.md pass with the count"   # "design-sync: 1 source checked, DESIGN.md matches tokens.json (sha256:"
t_begin "DESIGN.md changed after the tokens fails with both hashes" # exit 1; both full hashes; "rerun design-system"
t_begin "no DESIGN.md, no tokens.json or no sourceHash fails on zero input" # three runs, each "design-sync: 0 sources checked"
t_begin "a symlinked docs/design/DESIGN.md hashes the root file it points to" # DESIGN_SOURCE=docs/design/DESIGN.md -> same hash as DESIGN.md
t_begin "runs with sh and awk only (no bash, python3 or node)"  # PATH="$(minimal_path sh awk sed grep cat head tr sha256sum shasum openssl)"
```

- [ ] **Step 2: Run them to verify they fail**

Run: `bash tests/unit/design_sync.sh`
Expected: FAIL, the template does not exist.

- [ ] **Step 3: Implement `design-sync.sh`**

POSIX sh: hasher order `sha256sum`, `shasum -a 256`, `openssl dgst -sha256 -r`; read the recorded hash with `sed -n` on the `"sourceHash"` key (first match); `cat` follows a symlink.

- [ ] **Step 4: Write `from-impeccable.md` and edit SKILL.md**

Mapping: frontmatter `colors` to primitives and the light roles (primary as accent, neutral scale from the neutral entries); `typography` roles to `font.families` and `font.sizes`; `rounded` to `radius`; `spacing` to `space.scale`; sidecar `colorMeta` ramps, motion and breakpoints where present; dark roles designed by steps 3 and 4 as today; a seed placeholder is filled by this skill and listed as a proposal for the direction's owner. `meta.source` is `DESIGN.md (impeccable)`, `meta.sourcePath` `DESIGN.md`, `meta.sourceHash` from `sh scripts/design-sync.sh --hash`. Symlink: when `docs/design/DESIGN.md` is absent or is Bearing's guide (holds the template line ``Tokens live in `docs/design/tokens.json` ``), it becomes a relative symlink to `../../DESIGN.md`; any other file is left and reported under Noticed. The root `DESIGN.md` is never written by this skill. When impeccable later updates `DESIGN.md`, the check fails; rerunning design-system re-derives the tokens without writing `DESIGN.md`, so the check cannot loop. allowed-tools gains `Bash(sh scripts/design-sync.sh:*)`.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `bash tests/unit/design_sync.sh; bash tests/unit/design_lint.sh; make lint-skill-size lint-tools lint-portable`
Expected: `design_sync.sh: 6 cases, ... 0 failed`; design_lint unchanged and passing; lints exit 0.

- [ ] **Step 6: Commit**

```bash
chmod +x tests/unit/design_sync.sh
git add plugins/bearing/skills/design-system tests/unit/design_sync.sh
git commit -m "feat(design-system): derive tokens from impeccable's DESIGN.md and check its hash"
```

---

### Task 6: screen-design runs impeccable harden and polish, then its gates

**Files:**
- Create: `plugins/bearing/skills/screen-design/references/impeccable-pass.md`
- Modify: `plugins/bearing/skills/screen-design/SKILL.md` (Inputs line; a "### Impeccable pass" subsection after the two build paths; output contract; allowed-tools; the doctrine sentence says `design-doctrine.md` is the fallback when impeccable is absent)

**Interfaces:**
- Consumes: `impeccable.md` (Task 4), `design-sync.sh` (Task 5).

- [ ] **Step 1: Write `impeccable-pass.md`**

After every screen and state exists: `harden <screen set>` on the loading, empty and error panels, then `polish <screen set>`, per feature; target is the views under `src/features/<feature>/components/` (react-shadcn) or the pages under `docs/design/screens/<feature>/`. Brief: the flows file (copy fixed), `DESIGN.md` and `docs/design/tokens.json` as the binding system. A state the flows lack is raised as a gap, not written. After the pass rerun `gallery_check.py` or `states_check.py`, `bundle.py check`, `contrast.py`, `sh scripts/design-lint.sh` and, when installed, `sh scripts/design-sync.sh`; an edit that breaks one is reverted and listed. Unattended both run (neither asks under that brief). Absent: `impeccable not installed`, no pass.

- [ ] **Step 2: Edit SKILL.md**

Output contract line: `Impeccable: harden <n> and polish <n> screen sets | not installed; inferred: <facts> | none`. allowed-tools gains `Skill`, `Bash(printenv BEARING_AUTOPILOT BEARING_NONINTERACTIVE)`, `Bash(sh scripts/design-lint.sh:*)`, `Bash(sh scripts/design-sync.sh:*)`, `Bash(*skills/impeccable/scripts/impeccable *)`.

- [ ] **Step 3: Verify**

Run: `make lint-skills lint-skill-size lint-tools lint-questions`
Expected: each exits 0.

- [ ] **Step 4: Commit**

```bash
git add plugins/bearing/skills/screen-design
git commit -m "feat(screen-design): impeccable harden and polish pass before the state and contrast gates"
```

---

### Task 7: screen-design writes data-needs.md and checks it

**Files:**
- Create: `plugins/bearing/skills/screen-design/scripts/data_needs_check.py`
- Create: `plugins/bearing/skills/screen-design/templates/data-needs.md`
- Create: `plugins/bearing/skills/screen-design/references/data-needs.md`
- Modify: `plugins/bearing/skills/screen-design/SKILL.md` (a step after the screens; Inputs gate list; output contract; allowed-tools `Bash(python3 *skills/screen-design/scripts/data_needs_check.py*)`)
- Create: `tests/fixtures/data-needs/flows.md`, `tests/fixtures/data-needs/data-needs.md`
- Test: `tests/unit/screen_data_needs.sh` (create)

**Interfaces:**
- Consumes: `flows_check.inventory_full(text)` (loaded by path from `../../ux-flows/scripts/flows_check.py`, as `bundle.py` does) and `states_check.inventory(flows_path) -> {sid: [state]}` and `states_check.norm(state) -> str` (same directory).
- Produces (Tasks 8 and 11 use these):
  - `parse_needs(text: str) -> dict[str, dict[str, list[dict[str, str]]]]`: `{sid: {"fields": [...], "actions": [...], "states": [...]}}` from `## S-nn <name>` sections with `### Fields`, `### Actions`, `### States` tables; row keys are lower-cased headers. Fields `| Id | Field | Type | Source | Status |` (Id `F-nn`; Source `server`, `derived: <how>` or `client: <where>`); Actions `| Id | Action | Server | Outcomes | Status |` (Id `A-nn`; Server `none: <reason>` for a client-only action); States `| State | Server condition |`. Status is `exists` or `new` (greenfield: `new`). A row whose first cell is `none: <reason>` is kept as `{"none": "<reason>"}`.
  - `outcomes(cell: str) -> list[tuple[str, str]]`: `"201 created; 409 already_member"` gives `[("201", "created"), ("409", "already_member")]`.
  - CLI `data_needs_check.py --needs <file> --flows <flows.md>`; `problem:` lines, then `data-needs: N screens, F fields, A actions (E exists, W new), O outcomes, S states, P problems`; exit 1 on a problem, a missing file, or 0 screens in the inventory (`data-needs: 0 screens in the inventory (<flows>), nothing checked`).

Fixture (`tests/fixtures/data-needs/`): flows with S-01 Members (states loading, empty, `error: already_member`, success) and S-02 Invite (loading, `empty` as `n/a: reason`, error, success), story US-01-001, a Task paths row. Needs: F-01 `member.email` string server exists (S-01); F-02 `invite.expires_at` datetime server new (S-02); A-01 (S-01) Send invite, server "create an invite", outcomes `201 created; 409 already_member`, new; A-02 (S-02) Revoke, server "revoke the invite", outcomes `204 revoked`, exists; States rows for S-01 loading, empty, error: already_member and S-02 loading, error.

- [ ] **Step 1: Write the failing tests**

```bash
t_begin "a complete needs file passes with its counts"
# "data-needs: 2 screens, 2 fields, 2 actions (1 exists, 1 new), 3 outcomes, 5 states, 0 problems"
t_begin "a screen with no entry, an action with no outcome and an uncovered error state fail"
# "S-02 has no entry in"; "A-01 (S-01) has no outcome"; "S-01 state error-already-member has no server condition"
t_begin "a client-only action needs no outcome; none: needs a reason"
# Server "none: opens the picker locally" with blank Outcomes passes; a Fields row "none:" -> "none needs a reason"
t_begin "a status other than exists or new, and an outcome with no code, fail"
# "F-02 (S-02) status must be exists or new"; 'A-02 (S-02) outcome "204" has no code (write <status> <code>)'
t_begin "an action id used on two screens fails"   # "A-01 is used twice (S-01, S-02)"
t_begin "zero input fails"   # missing needs file; inventory with no screens -> "0 screens in the inventory"
```

- [ ] **Step 2: Run them to verify they fail**

Run: `bash tests/unit/screen_data_needs.sh`
Expected: FAIL, script not found.

- [ ] **Step 3: Implement `data_needs_check.py`, the template and the reference**

Server conditions are required for every inventory state whose normalised name starts with `error`, `empty` or `loading` and is not n/a. The template follows `lint-templates` (guidance comment, What and Good on each section). The reference states C2's content and, on a feature against an existing API, reading the existing contract and marking each need `exists` or `new`. SKILL.md step: write `docs/design/screens/<feature>/data-needs.md`, run `python3 "${CLAUDE_PLUGIN_ROOT}/skills/screen-design/scripts/data_needs_check.py" --needs <file> --flows <flows file>`, fix until it exits 0; output contract `Data needs: <data_needs_check.py counts line, verbatim>`; Next adds `data-model` and `openapi-spec` after design-critique.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bash tests/unit/screen_data_needs.sh; make lint-skill-size lint-tools lint-templates`
Expected: `screen_data_needs.sh: 6 cases, ... 0 failed`; lints exit 0.

- [ ] **Step 5: Commit**

```bash
chmod +x tests/unit/screen_data_needs.sh
git add plugins/bearing/skills/screen-design tests/fixtures/data-needs tests/unit/screen_data_needs.sh
git commit -m "feat(screen-design): write each feature's data needs and check them against the flows"
```

---

### Task 8: openapi-spec and data-model take the data needs as input

**Files:**
- Create: `plugins/bearing/skills/openapi-spec/scripts/needs_check.py`
- Modify: `plugins/bearing/skills/openapi-spec/SKILL.md` (Inputs: `docs/design/screens/*/data-needs.md`; step 2 maps actions, fields and outcomes; a step running needs_check; output contract; allowed-tools for both the `uv run ... needs_check.py` and `python3 *needs_check.py*` forms)
- Modify: `plugins/bearing/skills/openapi-spec/references/api-style.md` (the `x-data-needs` convention with its reason)
- Modify: `plugins/bearing/skills/data-model/scripts/model_check.py` (`--needs`), `plugins/bearing/skills/data-model/SKILL.md` (Inputs line; step 11 gate passes `--needs`; output contract; the Revising paragraph moves to `references/revising.md` to stay at 200 lines)
- Create: `tests/fixtures/data-needs/openapi.json`
- Test: `tests/unit/api_data_needs.sh` (create), `tests/unit/data_model_check.sh` (new case)

**Interfaces:**
- Consumes: `parse_needs`, `outcomes` (Task 7, loaded by path from `../../screen-design/scripts/data_needs_check.py`); `load(path)` from `api_doc.py` (same directory; JSON loads without PyYAML).
- Produces:
  - Operation extension `x-data-needs: [A-01, ...]`.
  - `needs_check.py --spec <openapi> --needs F [F ...]`; prints `data needs: N actions, M mapped, K new operations; O outcomes, U without a response, P problems`. N counts server actions (not `none:`); K counts operations whose `x-data-needs` holds an action with Status `new`. Exit 1 on a problem, zero actions, zero operations, or a missing file.
  - `model_check.py ... --needs F [F ...]`: adds `data needs: N fields, M stored, K derived, U unmapped`; a field with Status `new` and Source `server` is mapped when a data-dictionary Why cites its id; `derived:` counts in K; `exists` and `client:` fields are not counted in M, K or U. Zero fields with `--needs` exits 1.

Fixture `openapi.json`: `POST /invites` (`x-data-needs: [A-01]`, responses 201 and 409) and `DELETE /invites/{id}` (`x-data-needs: [A-02]`, response 204).

- [ ] **Step 1: Write the failing tests**

```bash
t_begin "every action mapped and every outcome documented passes"
# "data needs: 2 actions, 2 mapped, 1 new operations; 3 outcomes, 0 without a response, 0 problems"
t_begin "an action no operation maps fails"   # drop A-02 from DELETE -> "A-02 (Revoke) maps to no operation"
t_begin "an outcome with no response fails"   # drop 409 -> "A-01 outcome 409 already_member: no 409 response on POST /invites"
t_begin "an id no data-needs file has fails"  # x-data-needs: [A-09] -> "POST /invites x-data-needs names A-09, which no data-needs file has"
t_begin "an action id in two files fails"     # second feature file with A-01 -> "A-01 is in two files:"
t_begin "zero input fails"                     # spec with no operations; needs with no actions
```

In `data_model_check.sh`:

```bash
t_begin "--needs: a new server field must be cited by a Why, derived fields are counted"
# templates + fixture needs -> exit 1, "F-02 (invite.expires_at) is a new server field no data-dictionary Why cites"
# replace_in a Why to cite F-02 -> exit 0, "data needs: 2 fields, 1 stored, 0 derived, 0 unmapped"
```

- [ ] **Step 2: Run them to verify they fail**

Run: `bash tests/unit/api_data_needs.sh; bash tests/unit/data_model_check.sh`
Expected: FAIL, needs_check.py not found; model_check rejects `--needs`.

- [ ] **Step 3: Implement `needs_check.py` and `model_check.py --needs`, then edit both SKILL.md files**

openapi-spec step 2: each action becomes or maps to an operation (`x-data-needs`), each field a schema property, each outcome a documented response; existing inputs (stories, HLD interfaces, code routes, ADRs) stay. Run `uv run --quiet --with pyyaml==6.0.3 python "${CLAUDE_PLUGIN_ROOT}/skills/openapi-spec/scripts/needs_check.py" --spec api/openapi.yaml --needs docs/design/screens/*/data-needs.md` (no uv: the same with `python3`). Output contract `Data needs: <needs_check.py line, verbatim> | none (no screens)`. data-model Inputs: the data-needs files; each new server field becomes a column whose Why cites the field id, or is derived.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bash tests/unit/api_data_needs.sh; bash tests/unit/data_model_check.sh; bash tests/unit/pins_match.sh; make lint-skill-size lint-tools`
Expected: `api_data_needs.sh: 6 cases, ... 0 failed`; data_model_check passes with its new case; pins_match `, 0 problems`.

- [ ] **Step 5: Commit**

```bash
chmod +x tests/unit/api_data_needs.sh
git add plugins/bearing/skills/openapi-spec plugins/bearing/skills/data-model tests/fixtures/data-needs/openapi.json tests/unit/api_data_needs.sh tests/unit/data_model_check.sh
git commit -m "feat(openapi-spec, data-model): derive operations and columns from the screens' data needs"
```

---

### Task 9: design-critique folds in impeccable findings and counts task cost

**Files:**
- Modify: `plugins/bearing/skills/design-critique/SKILL.md` (description `eleven` to `twelve`; Inputs; a step after step 6; output contract rows; allowed-tools `Skill`, `Bash(printenv BEARING_AUTOPILOT BEARING_NONINTERACTIVE)`, `Bash(*skills/impeccable/scripts/impeccable *)`; step 2 detail moves to `references/measure-colour.md`)
- Modify: `plugins/bearing/skills/design-critique/references/review-checklist.md` (`## 12. Task cost (5%)`; `## 2. Typography (10%)`, from 15)
- Modify: `plugins/bearing/skills/design-directions/SKILL.md` (unattended scoring line: "the categories of the checklist, task cost n/a: the variants share the flows")

**Interfaces:**
- Consumes: `task paths:` line (Task 2), the six patterns (Task 3), `impeccable.md` (Task 4).

- [ ] **Step 1: Edit the checklist and the skill**

Task cost is counted, not judged: 10 minus 2 per task over budget without a reason (from the flows_check line) minus 1 per instance of the six patterns found on the screens, floor 0; each deduction is an evidence line naming the task or the screen id. Impeccable step: `audit <target>` whenever installed; `critique <target>` attended only; each finding kept with `source: impeccable audit` or `impeccable critique`; contrast, widths, themes and copy against flows stay Bearing-measured, and an impeccable finding that contradicts a measurement is listed with both. Output contract gains `| task cost | 8 | 5% | flows.md task paths; S-02 confirmation on a reversible action |` and `Impeccable: audit N findings, critique N | critique not run (unattended) | not installed`.

- [ ] **Step 2: Verify**

Run: `grep -oE '^## [0-9]+\. .*\(([0-9]+)%' plugins/bearing/skills/design-critique/references/review-checklist.md | grep -oE '[0-9]+%' | tr -d % | awk '{s+=$1} END {print NR, s}'`
Expected: `12 100`.
Run: `make lint-skills lint-skill-size lint-tools lint-questions; bash tests/unit/autopilot_stages.sh`
Expected: exit 0; the design_review case still passes.

- [ ] **Step 3: Commit**

```bash
git add plugins/bearing/skills/design-critique plugins/bearing/skills/design-directions/SKILL.md
git commit -m "feat(design-critique): impeccable audit and critique findings, and a counted task cost category"
```

---

### Task 10: Screens before the contract in the flows and the handbook

**Files:**
- Modify: `docs/flows.json`
- Modify: `bin/gen-guide.py` (STAGES rows: "Design direction" becomes `impeccable` (pack `impeccable`); "Three variants to choose from" output; "API contract" and "Data model" outputs; "Design review and iteration" says twelve categories; one NOTES line)
- Modify: `plugins/bearing/skills/workflow/SKILL.md:57` (Design row)
- Regenerate: `docs/SKILLS.md`, `docs/WORKFLOW.md`, `site/src/data/handbook.json`, `devguide/src/data/internals.json`, `plugins/bearing/bin/flow-steps.tsv`
- Test: `tests/unit/flow_order.sh` (create)

**Interfaces:**
- Produces: greenfield order in `flow-steps.tsv`: `high-level-design`, `architecture-diagram`, `plan-eng-review`, then `ux-flows`, `design-directions`, `design-system`, `screen-design`, `design-critique` (and the genai option), then `data-model`, `openapi-spec`, `threat-model`, `low-level-design`. Feature: the Screens option first; the API and data-model options say they take the screens' data needs.

- [ ] **Step 1: Write the failing test**

```bash
# pos <flow> <skill>: its order number in flow-steps.tsv
pos() { awk -F'\t' -v f="$1" -v s="$2" '$1==f && $3==s {print $2; exit}' "$KIT/plugins/bearing/bin/flow-steps.tsv"; }
before() { _t_count; [ -n "$(pos "$1" "$2")" ] && [ -n "$(pos "$1" "$3")" ] && [ "$(pos "$1" "$2")" -lt "$(pos "$1" "$3")" ] || _t_fail "$1: $2 is not before $3"; }
t_begin "greenfield: high-level design, then the screens, then the contract, then the low-level design"
before greenfield high-level-design ux-flows
before greenfield ux-flows design-directions; before greenfield design-directions design-system
before greenfield design-system screen-design; before greenfield screen-design data-model
before greenfield data-model openapi-spec; before greenfield openapi-spec threat-model
before greenfield threat-model low-level-design
t_end
t_begin "feature: screens come before the API and the data model"
before feature ux-flows openapi-spec; before feature screen-design data-model
t_end
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/unit/flow_order.sh`
Expected: FAIL, `greenfield: screen-design is not before data-model` (and design-directions has no position: today the step is `/design-consultation`).

- [ ] **Step 3: Edit flows.json, gen-guide.py and the workflow table, then regenerate**

Greenfield: move the "What does the product include?" branch to sit after `engreview`; the Screens option's `gf-direction` becomes `design-directions` (pack bearing, does: one impeccable direction round over the real screens, three variants without it); then `datamodel`, `apicontract`, `threats` with does lines saying they read `docs/design/screens/<feature>/data-needs.md`; `f-screens` output names `data-needs.md`. Feature: move the "Screens" option first; `f-api` and `f-data` does lines say they take the screens' data needs when the change has screens. Workflow row: `ux-flows`, `design-directions` (impeccable), `design-system`, `screen-design`, then `data-model`, `openapi-spec`.

Run: `make docs`
Expected: `gen-flow-steps: 4 flows, N steps` and the other generators' lines; `git status` shows the five generated files changed.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bash tests/unit/flow_order.sh; bash tests/unit/session_resume.sh; make lint-docs`
Expected: `flow_order.sh: 2 cases, 10 assertions, 0 failed`; session_resume passes; `lint-docs: 5 generated docs up to date`.

- [ ] **Step 5: Commit**

```bash
chmod +x tests/unit/flow_order.sh
git add docs/flows.json bin/gen-guide.py plugins/bearing/skills/workflow/SKILL.md docs/SKILLS.md docs/WORKFLOW.md site/src/data/handbook.json devguide/src/data/internals.json plugins/bearing/bin/flow-steps.tsv tests/unit/flow_order.sh
git commit -m "feat(flows): screens before the data model, API contract and threat model"
```

---

### Task 11: Autopilot splits the design stage so screens come before the contract

**Files:**
- Modify: `plugins/bearing/bin/brg-autopilot` (STAGES `design` text, new `contract` row after `ux`; `g_design`; new `g_contract`; `GATES`; `ux_screens_as_code` accepts an impeccable pick)
- Modify: `plugins/bearing/skills/autopilot/SKILL.md:63`, `references/design-stages.md`, `references/stage-skills-and-scope.md`, `references/auto-mode-and-profile.md`
- Test: `tests/unit/autopilot_stages.sh`

**Interfaces:**
- Consumes: `data_needs_check.py`, `needs_check.py`, `model_check.py --needs` (Tasks 7, 8) through `checker(d, rel_script, *args)`; `approved.json` shape (Task 4).
- Produces: stage order `repo branch prd stories decide architecture design repos ux contract lld test_cases build test_automation design_review review dod mr`; `g_contract(d: str, st: dict) -> tuple[bool, str]`.
  - `design` (scope full): HLD passing arch_check, deployment architecture (profile deploy), GenAI solution (profile llm). Pass line starts `HLD <n>`.
  - `contract` (scope full): data model passing model_check (profile data; with `--needs` when data-needs files exist), `api/openapi.yaml` (profile api), threat models passing threats_check; profile ui and api: at least one `docs/design/screens/*/data-needs.md` and needs_check passing. Lean: `scope lean: the design note covers the contract`. Pass line `data model, API contract, threat models <n>; <needs_check line>`.
  - `ux_screens_as_code`: an `approved.json` with `source` `impeccable`, a non-empty `chosen` and at least one challenger counts as a chosen direction; the three-scored-variants rule stays for `source` `bearing` or absent.

- [ ] **Step 1: Write the failing tests**

```bash
# stage order assertion becomes:
assert_eq "repo branch prd stories decide architecture design repos ux contract lld test_cases build test_automation design_review review dod mr" "..." "stage order"
t_begin "design requires the HLD and the deployment the profile names"
# from today's case: no data-model or openapi assertions; pass line "HLD 1, deployment with 1 diagram(s)"
t_begin "contract requires the data model, API contract and threat model, from the screens' data needs"
# at contract; profile yes yes yes yes; missing data-model.md, api/openapi.yaml -> named
# threats missing -> "docs/security/threat-model-*.md (threat-model"
# ui+api without data-needs -> "no docs/design/screens/*/data-needs.md (screen-design"
# copy tests/fixtures/data-needs/data-needs.md to docs/design/screens/invites/ and openapi.json to api/openapi.yaml;
# datamodel, then replace_in one data-dictionary Why to cite F-02 (model_check --needs runs here)
# pass: "data model, API contract, threat models 1; data needs: 2 actions, 2 mapped"
t_begin "a full-scope profile without data or API needs only the threat model at contract"
# "threat models 1; profile: data=no api=no"
t_begin "an impeccable pick counts as the chosen direction on react-shadcn"
# approved.json {"source": "impeccable", "chosen": "harbour", "challengers": ["ledger"]} -> passes the direction check
# {"source": "impeccable", "chosen": "harbour", "challengers": []} -> "picked over no challenger"
```

The GenAI case moves its threat-model assertions to `contract`; the lean case gains `assert_exit 0 ap "done" contract` with `scope lean`.

- [ ] **Step 2: Run them to verify they fail**

Run: `bash tests/unit/autopilot_stages.sh`
Expected: FAIL on the stage order.

- [ ] **Step 3: Implement the split and edit the autopilot references**

`design-stages.md`: design runs high-level-design, deployment-architecture and genai-design; repos; ux (flows, direction, system, motion, screens, data needs); contract runs data-model, openapi-spec and threat-model from the data needs; then lld.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bash tests/unit/autopilot_stages.sh; bash tests/unit/autopilot_state.sh; bash tests/unit/autopilot_smoke.sh`
Expected: each `... 0 failed`.

- [ ] **Step 5: Commit**

```bash
git add plugins/bearing/bin/brg-autopilot plugins/bearing/skills/autopilot tests/unit/autopilot_stages.sh
git commit -m "feat(autopilot): a contract stage after ux, so the API and data model follow the screens"
```

---

### Task 12: Eval cases for the changed behaviour

**Files:**
- Modify: `evals/ux-flows/evals.json` (id 3), `evals/screen-design/evals.json` (id 3), `evals/openapi-spec/evals.json` (id 3), `evals/design-directions/evals.json` (ids 3 and 4)
- Create: `evals/openapi-spec/files/po-screens/` (a copy of `files/po-backlog` plus `docs/design/flows/po/flows.md` and `docs/design/screens/po/data-needs.md`)

**Interfaces:**
- Consumes: skill-creator's case schema (`id`, `name`, `prompt`, `expected_output`, `files`, `expectations`).

- [ ] **Step 1: Write the cases**

- ux-flows 3 `task-over-budget` (files `files/team-invites`; the prompt says the old invite was a five-step wizard): expectations include a `## Task paths` row per covered story with counts, the `task paths:` line printed verbatim, the invite redesigned within 3 screens and 6 interactions with a named pattern (one form, a sheet) or an `over:` reason from the legitimate list, and the remove-member confirmation kept.
- screen-design 3 `data-needs-written` (files `files/clinic-booking`): `docs/design/screens/<feature>/data-needs.md` with fields, actions with outcomes and states per screen; each flows error row has a server condition; needs marked `exists` or `new` against `src/api/booking.js`; the `data-needs:` line printed verbatim.
- openapi-spec 3 `operations-from-data-needs` (files `files/po-screens`): every action maps by `x-data-needs`, every outcome is a documented response, the `data needs:` line printed verbatim, stories still cited.
- design-directions 3 `impeccable-absent-fallback` (files `files/shipment-tracking`, impeccable not installed): prints `impeccable not installed` once, three variants as today, `approved.json` with `source: bearing`, no question about installing it.
- design-directions 4 `unattended-no-impeccable-round` (files `files/kiosk-checkin`, prompt asks for an unattended run): no question asked, no impeccable init or seed round, the fallback runs, the report says the round was skipped because the run is unattended.

- [ ] **Step 2: Verify**

Run: `make lint-evals lint-json lint-prose`
Expected: each exits 0. Running the evals with skill-creator: not run here (state "not run" in the report unless the user asks for a benchmark).

- [ ] **Step 3: Commit**

```bash
git add evals/ux-flows evals/screen-design evals/openapi-spec evals/design-directions
git commit -m "test(evals): task budget, data needs, operations from data needs, impeccable fallback"
```

---

### Task 13: CHANGELOG and the full gate

**Files:**
- Modify: `CHANGELOG.md` (under `## [Unreleased]`)

- [ ] **Step 1: Write the entries**

Added: impeccable pinned and installed in the standard profile (doctor reports it); one impeccable direction round in design-directions; `design-sync` hash check; impeccable harden and polish in screen-design; `data-needs.md` and its check; `needs_check.py` and `model_check.py --needs`; task cost category. Changed: `flows_check.py` requires `## Task paths` (a flows file without it now fails; add the section); greenfield and feature flows put screens before the data model, API contract and threat model; autopilot gains a `contract` stage after `ux`; critique weights (typography 10%, task cost 5%). Noted: impeccable `critique` asks at its close, so it does not run unattended.

- [ ] **Step 2: Run the full gate**

Run: `make docs && git status --short`
Expected: no generated file changes (Task 10 committed them).
Run: `make check`
Expected: last line `check: passed`.

- [ ] **Step 3: Commit**

```bash
git add CHANGELOG.md
git commit -m "docs(changelog): design pipeline under Unreleased"
```

The engineer runs `make gate` and pushes; Bearing prints the commands and never runs `git push`.
