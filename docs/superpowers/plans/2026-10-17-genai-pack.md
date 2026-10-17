# GenAI Pack (phase 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship `bearing-genai` as a fourth plugin holding every GenAI and ML skill, with current model ids, evals that separate signal from noise, cost-based model routing, dataset generation and a GenAI flow.

**Architecture:** The 12 GenAI and ML skills move by `git mv` from `plugins/bearing/skills/` to `plugins/bearing-genai/skills/`, wired like `bearing-backend` (marketplace entry, `brg-kit-paths` sibling, version lockstep). Three stdlib Python gates (`eval_stats.py`, `route_frontier.py`, `dataset_check.py`) carry the new decisions; two new skills (`model-routing`, `dataset-generation`) and a deepened `llm-eval` call them. `docs/flows.json` gains a `genai` flow linked from greenfield and feature.

**Tech Stack:** bash 3.2, Python 3 stdlib, GNU make, Claude Code plugin manifests, JSON.

**Spec:** `docs/superpowers/specs/2026-10-17-genai-pack-design.md`

## Global Constraints

- No em dashes in any file (`make lint-prose`).
- Every gate fails on zero input and prints the count it checked. Scripts here: exit 0 pass, 1 check failed, 2 usage error or nothing to check (prints "nothing checked").
- `SKILL.md` at most 200 lines; `llm-guardrails` keeps its 217-line allowance at its new path.
- A skill that asks uses AskUserQuestion in `allowed-tools` and names `references/console.md` (the bearing plugin's file, as text).
- Every command a skill body runs is granted in `allowed-tools`; script grants use the form `Bash(python3 *skills/<skill>/scripts/<file>.py*)`.
- Python 3 stdlib only; bash 3.2 portable; no `sed -i`, `grep -P`, `readlink -f`, `date -d`.
- No new external fetch (nothing added to `pinned-packs.txt`).
- Default model ids: `claude-opus-5-5` (deep, default tier), `claude-sonnet-5-5` (balanced), `claude-haiku-4-5-20251001` (fast). Options: `claude-fable-5-1`, `claude-haiku-5-5`.
- References from `bearing-genai` to bearing skills are `bearing:<name>`; from bearing to moved skills `bearing-genai:<name>`.
- Every new skill: `## Inputs`, `## Steps`, `## Output contract`, `## Gotchas`; description at most 220 chars with "Use when" and two quoted phrases; `evals/<name>/evals.json`; 3 should and 2 near-miss rows in `evals/triggers.json`; a name in `gen-guide.py` CATEGORY `genai`.
- Bearing never pushes, merges or tags. Commits only on `feat/GenAIPack`, no attribution trailer.
- Run `make docs` after any change to a skill, flows.json or gen-guide.py, and commit the regenerated files.

## Review Focus

1. A user with only `bearing` installed asks autopilot for an LLM product: `profile --llm yes` must exit 2 naming `bearing-genai@bearing`, not record the profile and fail later at design. (Task 2 test.)
2. An eval results file where a fallback ran mid-run holds two `model` values: `route_frontier.py` must refuse it, not average two models into one candidate. (Task 5 test `mixed models`.)
3. A candidate with no price (`cost_usd: null`) must be refused, never treated as free and chosen as cheapest. (Task 5 test `no price`.)
4. `compare` on two runs that share no case ids (a renamed golden set) must exit 2, not report "no difference". (Task 4 test `no shared ids`.)
5. A training row that is a near copy of a golden-set case (case and whitespace changed) must count as contamination. (Task 6 test `contamination survives normalisation`.)

---

## File Structure

```
plugins/bearing-genai/                         new plugin (Task 1)
  .claude-plugin/plugin.json  README.md  LICENSE
  skills/{genai-design,rag,llm-agent,llm-eval,llm-fine-tuning,llm-gateway,
          llm-guardrails,prompt-registry,speech,mcp-server,computer-vision,
          tabular-ml}/                         moved from plugins/bearing/skills
  skills/llm-eval/scripts/eval_stats.py        Task 4
  skills/llm-eval/references/eval-methods.md   Task 4
  skills/model-routing/{SKILL.md,references/strategies.md,scripts/route_frontier.py}   Task 5
  skills/dataset-generation/{SKILL.md,references/generation.md,templates/DATASHEET.md,
                             scripts/dataset_check.py}                                 Task 6
bin/model-ids.txt  bin/lint-model-ids.py       Task 3
tests/unit/{model_ids.sh,eval_stats.sh,route_frontier.sh,dataset_check.sh}             Tasks 3-6
evals/{model-routing,dataset-generation}/      Tasks 5-6
docs/flows.json                                Task 7 (genai flow)
```

Modified across tasks: `.claude-plugin/marketplace.json`, `Makefile`, `plugins/bearing/bin/{brg-kit-paths,brg-doctor,brg-autopilot,brg-session}`, `install.sh`, `bin/{kit_paths.py,lint-version.py,trigger-eval.py,skill-evals.py,gen-guide.py,lint-skill-size.allow,lint-templates.skip}`, `tests/unit/{pins_match.py,llm_callsites.sh,ai_depth_scripts.sh,lint_skills_refs.sh,install_dry_run.sh,autopilot_stages.sh,session_resume.sh}`, `tests/integration/{plugin_split.sh,doctor_matrix.sh}`, `evals/triggers.json`, `site/src/lib/nav.ts`, `site/src/pages/Home.tsx`, docs and READMEs, generated docs.

---

### Task 1: The `bearing-genai` plugin, with the 12 skills moved into it

**Files:**
- Create: `plugins/bearing-genai/.claude-plugin/plugin.json`, `plugins/bearing-genai/README.md`, `plugins/bearing-genai/LICENSE` (copy of `plugins/bearing-backend/LICENSE`)
- Move: `plugins/bearing/skills/<12 names>/` to `plugins/bearing-genai/skills/<12 names>/` (`git mv`)
- Modify: `.claude-plugin/marketplace.json`, `plugins/bearing/bin/brg-kit-paths:4-8,32-40`, `Makefile:1-3,25,64-67` (comment, lint-skills help and the `bearing(-backend|-apps)?:` regex), `bin/kit_paths.py` (docstrings), `bin/lint-version.py` (docstring), `bin/lint-skill-size.allow:11`, `bin/lint-templates.skip:3-16,41`, `tests/unit/pins_match.py:33-34`, `tests/unit/llm_callsites.sh:2,9`, `tests/unit/ai_depth_scripts.sh:9`
- Modify (references): moved `SKILL.md` files; `plugins/bearing/skills/workflow/SKILL.md:58`, `plugins/bearing/skills/autopilot/references/{design-stages.md,auto-mode-and-profile.md,build-and-after.md}`, `plugins/bearing/skills/tech-decision/references/catalogue.md:197-199`, `plugins/bearing/skills/high-level-design/references/traps.md:70`, `plugins/bearing/skills/observability/references/telemetry-conventions.md:94`
- Test: `tests/integration/plugin_split.sh`, `tests/unit/lint_skills_refs.sh`

**Interfaces:**
- Produces: `brg-kit-paths --skill <moved name>` prints `<root>/plugins/bearing-genai/skills/<name>`; `--owner <moved or new name>` prints `bearing-genai`; `--install-hint rag` prints `rag is in the bearing-genai plugin, which is not installed: /plugin install bearing-genai@bearing (or claude plugin install bearing-genai@bearing)`. Skill names owned by bearing-genai, used by every later task: `genai-design rag llm-agent llm-eval llm-fine-tuning llm-gateway llm-guardrails prompt-registry speech mcp-server computer-vision tabular-ml model-routing dataset-generation`.

- [ ] **Step 1: Write the failing tests in `tests/integration/plugin_split.sh`**

Change the first case to four roots and add the genai lookups:

```bash
t_begin "the repository layout: four skill roots, bearing first"
assert_exit 0 bash "$P/bearing/bin/brg-kit-paths"
assert_eq 4 "$(printf '%s\n' "$T_OUT" | grep -c '/skills$')" "skill roots"
# (existing bearing-first, go, react, version asserts stay)
assert_exit 0 bash "$P/bearing/bin/brg-kit-paths" --skill rag
assert_eq "$P/bearing-genai/skills/rag" "$T_OUT"
assert_exit 0 bash "$P/bearing/bin/brg-kit-paths" --owner model-routing
assert_eq "bearing-genai" "$T_OUT"
assert_eq 0 "$(ls -d "$P"/bearing/skills/rag "$P"/bearing/skills/llm-eval 2>/dev/null | wc -l | tr -d ' ')" "moved skills gone from bearing"
t_end
```

In "every plugin stands alone", scan `"$P/bearing-genai"` as well, keep the bin/templates/agents/hooks ban, and allow `CLAUDE_PLUGIN_ROOT}/skills/<x>/...` only when the referenced path exists under that file's own plugin root:

```bash
# for each match of 'CLAUDE_PLUGIN_ROOT\}?/skills/[A-Za-z0-9_./-]+' in $f:
#   own="${f%%/skills/*}"; rel="${match#*CLAUDE_PLUGIN_ROOT}"; rel="${rel#\}}"
#   [ -e "$own$rel" ] || bad="$bad ${f#"$KIT"/}"
```

In "bearing alone", add:

```bash
assert_exit 1 bash "$solo/bin/brg-kit-paths" --skill rag
assert_contains "$T_OUT" "rag is in the bearing-genai plugin, which is not installed: /plugin install bearing-genai@bearing"
```

In `tests/unit/lint_skills_refs.sh`, add a case beside the existing cross-plugin one: a skill text naming `bearing-genai:rag` passes and `bearing-genai:no-such-skill` fails with `unknown name 'bearing-genai:no-such-skill'`.

- [ ] **Step 2: Run them to verify they fail**

Run: `bash tests/integration/plugin_split.sh; bash tests/unit/lint_skills_refs.sh`
Expected: FAIL on `skill roots` (3, wanted 4), on `--skill rag`, and on `bearing-genai:rag` reported unknown.

- [ ] **Step 3: Create the plugin and move the skills**

`plugin.json`: name `bearing-genai`, version from `VERSION` (0.8.0 until Task 8), the description from spec section A, author, homepage, repository, license MIT, keywords `llm rag agents mcp evals model-routing datasets fine-tuning speech computer-vision`. `README.md` in the shape of `plugins/bearing-backend/README.md` listing the 12 skills (Tasks 5 and 6 add theirs) and `/plugin install bearing-genai@bearing`. Marketplace: a fourth entry after `bearing-apps` with source `./plugins/bearing-genai`, the same author, homepage, license, category; the metadata description becomes "bearing (required: the workflow, agents, hooks and templates), bearing-backend and bearing-apps (optional stack conventions), bearing-genai (optional GenAI and ML skills)." `git mv` each of the 12 directories.

- [ ] **Step 4: Teach the resolver and the lints**

`brg-kit-paths`: `SIBLINGS="bearing-backend bearing-apps bearing-genai"`; `owner_of` gains `genai-design|rag|llm-agent|llm-eval|llm-fine-tuning|llm-gateway|llm-guardrails|prompt-registry|speech|mcp-server|computer-vision|tabular-ml|model-routing|dataset-generation) echo bearing-genai;;`; the header comment says four plugins. Makefile lint-skills regex becomes `'\bbearing(-backend|-apps|-genai)?:[a-z0-9]+(-[a-z0-9]+)*'`. Update the paths in `bin/lint-skill-size.allow`, `bin/lint-templates.skip`, `tests/unit/pins_match.py`, `tests/unit/llm_callsites.sh` (`CHK=$KIT/plugins/bearing-genai/...`) and `tests/unit/ai_depth_scripts.sh` (`SK="$KIT/plugins/bearing-genai/skills"`).

- [ ] **Step 5: Rewrite cross-plugin references**

In the moved skills: the three decision-protocol lines (`genai-design`, `llm-gateway`, `rag`) take the `bearing-backend/skills/infra/SKILL.md:17-23` form with `bearing:tech-decision`; `speech`'s Decisions-first line names `bearing:tech-decision`; the `${CLAUDE_PLUGIN_ROOT}/references/console.md` in `llm-guardrails:46` and `mcp-server:49` becomes "the bearing plugin's `references/console.md`"; each mention of a bearing skill (`tech-decision`, `adr`, `observability`, `db-migration`, `ci-pipeline`, `high-level-design`) gets the `bearing:` prefix. In bearing: each moved name in the files listed above gets `bearing-genai:`.

- [ ] **Step 6: Run the tests and the gate**

Run: `bash tests/integration/plugin_split.sh && bash tests/unit/lint_skills_refs.sh && make docs && make check`
Expected: both tests PASS; `lint-plugin-size:` shows `bearing 451 files` (at most 455) and `bearing-genai 60 files`; `lint-skills:` shows `bearing-genai=12`; `check: passed`.

- [ ] **Step 7: Commit**

```bash
git add -A plugins .claude-plugin Makefile bin tests docs site/src/data devguide/src/data
git commit -m "feat: move the GenAI and ML skills into the bearing-genai plugin"
```

---

### Task 2: Install, doctor, autopilot dependency and the docs that name the plugins

**Files:**
- Modify: `install.sh:11,75,99`, `plugins/bearing/bin/brg-doctor:67-73`, `plugins/bearing/bin/brg-autopilot` (`cmd_profile`), `bin/trigger-eval.py:42,48`, `bin/skill-evals.py:91,242,257`, `README.md:30-38,180,295`, `docs/INSTALL.md:28-33,69,222`, `CONTRIBUTING.md:76,103`, `plugins/bearing/README.md:34`, `plugins/bearing-backend/README.md:31`, `plugins/bearing-apps/README.md:32`, `plugins/bearing/skills/new-skill/SKILL.md:40`, `plugins/bearing/.claude-plugin/plugin.json` (description, if it lists plugins), `devguide/src/pages/Start.tsx:68,77`
- Test: `tests/unit/install_dry_run.sh`, `tests/integration/doctor_matrix.sh`, `tests/unit/autopilot_stages.sh`

**Interfaces:**
- Consumes: `brg-kit-paths --skill genai-design` and `--install-hint genai-design` (Task 1).
- Produces: `brg-autopilot profile ... --llm yes` exits 2 with stderr `profile llm: genai-design is in the bearing-genai plugin, which is not installed: /plugin install bearing-genai@bearing (or claude plugin install bearing-genai@bearing); no profile recorded` when the skill does not resolve.

- [ ] **Step 1: Write the failing tests**

`install_dry_run.sh`: `assert_contains "$T_OUT" "would run  claude plugin install bearing-genai@bearing"`, the uninstall question now `(bearing, bearing-backend, bearing-apps, bearing-genai)`, and `absent     plugin bearing-genai@bearing`. `doctor_matrix.sh`: `assert_contains "$T_OUT" "optional  plugin bearing-genai not installed; its GenAI and ML skills are unavailable (claude plugin install bearing-genai@bearing)"`. `autopilot_stages.sh`, a new case after line 160:

```bash
t_begin "an llm profile without bearing-genai is refused before it is recorded"
at design
assert_exit 2 env BEARING_PLUGIN_DIRS=/nonexistent python3 "$AP" profile --ui no --data no --api no --deploy no --llm yes --scope full --why fixture --dir "$d"
assert_contains "$T_OUT" "genai-design is in the bearing-genai plugin, which is not installed: /plugin install bearing-genai@bearing"
assert_contains "$T_OUT" "no profile recorded"
assert_not_contains "$(ap status)" "llm=yes"
t_end
```

- [ ] **Step 2: Run them to verify they fail**

Run: `bash tests/unit/install_dry_run.sh; bash tests/integration/doctor_matrix.sh; bash tests/unit/autopilot_stages.sh`
Expected: FAIL on the three new asserts.

- [ ] **Step 3: Implement**

`install.sh`: `PLUGINS="bearing bearing-backend bearing-apps bearing-genai"` and the two prose lines. `brg-doctor`: the loop names four plugins and prints, for `bearing-genai`, "its GenAI and ML skills are unavailable" (stack plugins keep "its stack skills and templates are unavailable"). `cmd_profile`: when `a.llm == "yes"`, run `brg-kit-paths --skill genai-design` beside the script (`os.path.join(os.path.dirname(__file__), "brg-kit-paths")`, through `bash`, environment inherited); on a non-zero exit print `profile llm: <hint>; no profile recorded` to stderr and return 2 before `load`. `trigger-eval.py` and `skill-evals.py` name four plugins. Docs: each list of plugins gains `bearing-genai` ("GenAI and ML skills: RAG, agents, MCP, gateway and routing, evals, datasets, speech, vision, tabular ML", optional). `new-skill` says GenAI and ML skills go in `plugins/bearing-genai`.

- [ ] **Step 4: Run the tests and the gate**

Run: `bash tests/unit/install_dry_run.sh && bash tests/integration/doctor_matrix.sh && bash tests/unit/autopilot_stages.sh && make docs && make check`
Expected: all PASS; `check: passed`.

- [ ] **Step 5: Commit**

```bash
git add -A install.sh plugins bin tests README.md docs CONTRIBUTING.md devguide site/src/data
git commit -m "feat: install, doctor and autopilot know the bearing-genai plugin"
```

---

### Task 3: Current model ids and `lint-model-ids`

**Files:**
- Create: `bin/model-ids.txt`, `bin/lint-model-ids.py`, `tests/unit/model_ids.sh`
- Modify: `Makefile` (target `lint-model-ids`, added to `check` and `.PHONY`), every file under `plugins/bearing-genai/` that names a Claude id (from the grep in Step 3), `plugins/bearing-genai/skills/llm-gateway/templates/routing.yaml`

**Interfaces:**
- Produces: `python3 bin/lint-model-ids.py [root]` prints `lint-model-ids: F files scanned, I ids found (D defaults, O options), 0 unknown`; exit 1 listing `unknown model id <id> in <file>:<line>`; exit 2 `lint-model-ids: 0 files under plugins/, nothing checked`. `bin/model-ids.txt` rows `default|<id>|<tier>` and `option|<id>|<why>`, `#` comments.

- [ ] **Step 1: Write the failing test `tests/unit/model_ids.sh`**

```bash
t_begin "the repository has only listed ids"
assert_exit 0 python3 "$KIT/bin/lint-model-ids.py"
assert_contains "$T_OUT" "0 unknown"
t_end
t_begin "an unlisted id fails with its place"
r="$(tmpdir)"; mkdir -p "$r/plugins/p/skills/s" "$r/bin"; cp "$KIT/bin/model-ids.txt" "$r/bin/"
printf 'model: claude-opus-5\nmodel: claude-opus-5-5\n' > "$r/plugins/p/skills/s/SKILL.md"
assert_exit 1 python3 "$KIT/bin/lint-model-ids.py" "$r"
assert_contains "$T_OUT" "unknown model id claude-opus-5 in plugins/p/skills/s/SKILL.md:1"
assert_not_contains "$T_OUT" "claude-opus-5-5 in"
t_end
t_begin "a dated snapshot is one id, not its alias plus digits"
printf 'claude-haiku-4-5-20251001\n' > "$r/plugins/p/skills/s/SKILL.md"
assert_exit 0 python3 "$KIT/bin/lint-model-ids.py" "$r"
t_end
t_begin "no files is a failure"
e="$(tmpdir)"; mkdir -p "$e/plugins" "$e/bin"; cp "$KIT/bin/model-ids.txt" "$e/bin/"
assert_exit 2 python3 "$KIT/bin/lint-model-ids.py" "$e"
assert_contains "$T_OUT" "nothing checked"
t_end
t_summary
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/unit/model_ids.sh`
Expected: FAIL, `bin/lint-model-ids.py` not found.

- [ ] **Step 3: Implement**

`bin/model-ids.txt` holds the five rows in spec section B. The lint reads files from `git ls-files -co --exclude-standard -- plugins` when the root is a git work tree, else walks `plugins/`; skips binary files; matches `claude-(opus|sonnet|haiku|fable|mythos)-[0-9]+(-[0-9]+)*` as a whole token (not followed by `[0-9a-z]`). Then replace every unknown id under `plugins/bearing-genai/`: `claude-opus-5` to `claude-opus-5-5`, `claude-sonnet-5` to `claude-sonnet-5-5`, `claude-haiku-4-5` to `claude-haiku-4-5-20251001`, adjusting prose ("Opus 5" to "Opus 5.5", "Haiku 4.5" stays). In `routing.yaml`: `claude-opus-5-5` input 4.00, output 20.00, cache_read_multiplier 0.05; `claude-sonnet-5-5` 2.00, 10.00, 0.10; `claude-haiku-4-5-20251001` 1.00, 5.00, 0.10; cache_write_multiplier 1.25 each; a header line `# Prices: claude-api skill shared/models.md, as_of 2026-10-17. Re-read them there; never from memory.` Opus 5.5 thinking cannot be disabled and its default effort is medium: the `llm-gateway` Gotcha about Opus 5 becomes "Opus 5.5 and Sonnet 5.5 reject `budget_tokens` and sampling parameters; control depth with `output_config.effort` per route."

- [ ] **Step 4: Run the test and the gate**

Run: `bash tests/unit/model_ids.sh && make docs && make check`
Expected: PASS; `lint-model-ids: <F> files scanned, ... 0 unknown`; `check: passed`.

- [ ] **Step 5: Commit**

```bash
git add -A bin Makefile tests/unit/model_ids.sh plugins/bearing-genai docs site/src/data devguide/src/data
git commit -m "feat: current Claude model ids, held by lint-model-ids"
```

---

### Task 4: `llm-eval` statistics, judge calibration and run records

**Files:**
- Create: `plugins/bearing-genai/skills/llm-eval/scripts/eval_stats.py`, `plugins/bearing-genai/skills/llm-eval/references/eval-methods.md`, `tests/unit/eval_stats.sh`
- Modify: `plugins/bearing-genai/skills/llm-eval/SKILL.md` (steps 3 to 6, output contract, allowed-tools), `plugins/bearing-genai/skills/llm-gateway/templates/gateway-python.md` and `gateway-typescript.md` (`model_override`), `plugins/bearing-genai/skills/llm-gateway/SKILL.md` step 3 (one line), `evals/llm-eval/evals.json` (case 3)

**Interfaces:**
- Produces, results row schema (written by every harness, read by Tasks 5 and 6): `{"case_id": str, "score": float 0..1, "model": str, "usage": object, "cost_usd": float|null, "latency_ms": int, "truncated": bool, "valid": bool|null, "label": str|null}`.
- Produces, CLI (`ES=.../llm-eval/scripts/eval_stats.py`):
  - `python3 $ES summary <results.jsonl> [--resamples 2000] [--seed 7]` prints `eval-stats: N cases (T truncated, excluded), mean M, 95% CI [L, U]`, where N counts the rows that are not truncated.
  - `python3 $ES compare <base.jsonl> <new.jsonl> [...]` prints `eval-compare: S shared cases (base B, new W), delta +D, 95% CI [+L, +U]: better|worse|no difference`; exit 1 on worse.
  - `python3 $ES agree <people.jsonl> <judge.jsonl> [--min-items 30] [--min-kappa 0.6]` reads `label` from both; prints `eval-agree: S shared items, agreement A, kappa K: calibrated|uncalibrated`; exit 1 on uncalibrated.
  - Every subcommand: exit 2 with `nothing checked` on zero cases or zero shared ids.
- Produces: `LLMRequest.model_override: str | None` (Python) / `modelOverride?: string` (TypeScript), honoured only when `LLM_ALLOW_MODEL_OVERRIDE=1`, else raises `ModelOverrideRefused` before any call.

- [ ] **Step 1: Write the failing test `tests/unit/eval_stats.sh`**

Fixtures by heredoc; `row id score` helper writes `{"case_id":"<id>","score":<s>,"model":"m","truncated":false}`.

```bash
t_begin "summary: mean and an interval that holds it; truncated excluded and counted"
# 4 rows: scores 1,1,0,1 plus one truncated row
assert_exit 0 python3 "$ES" summary "$d/a.jsonl"
assert_contains "$T_OUT" "eval-stats: 4 cases (1 truncated, excluded), mean 0.750"
t_end
t_begin "compare: identical runs are no difference"
assert_exit 0 python3 "$ES" compare "$d/a.jsonl" "$d/a.jsonl"
assert_contains "$T_OUT" "delta +0.000"; assert_contains "$T_OUT" ": no difference"
t_end
t_begin "compare: 40 shared cases all improving 0 to 1 is better; the reverse is worse and exits 1"
assert_exit 0 python3 "$ES" compare "$d/zeros.jsonl" "$d/ones.jsonl"; assert_contains "$T_OUT" "40 shared cases"; assert_contains "$T_OUT" ": better"
assert_exit 1 python3 "$ES" compare "$d/ones.jsonl" "$d/zeros.jsonl"; assert_contains "$T_OUT" ": worse"
t_end
t_begin "compare: no shared ids exits 2"
assert_exit 2 python3 "$ES" compare "$d/a.jsonl" "$d/other-ids.jsonl"; assert_contains "$T_OUT" "nothing checked"
t_end
t_begin "agree: perfect agreement on 30 items is kappa 1.00, calibrated"
assert_exit 0 python3 "$ES" agree "$d/people.jsonl" "$d/people.jsonl"; assert_contains "$T_OUT" "kappa 1.00: calibrated"
t_end
t_begin "agree: fewer than 30 shared items is uncalibrated"
assert_exit 1 python3 "$ES" agree "$d/people10.jsonl" "$d/people10.jsonl"; assert_contains "$T_OUT" "uncalibrated"
t_end
t_begin "summary: an empty file exits 2"
: > "$d/empty.jsonl"; assert_exit 2 python3 "$ES" summary "$d/empty.jsonl"; assert_contains "$T_OUT" "nothing checked"
t_end
t_begin "the same seed gives the same interval"
a="$(python3 "$ES" summary "$d/a.jsonl" --seed 3)"; b="$(python3 "$ES" summary "$d/a.jsonl" --seed 3)"; assert_eq "$a" "$b"
t_end
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/unit/eval_stats.sh`
Expected: FAIL, script not found.

- [ ] **Step 3: Implement `eval_stats.py`**

Percentile bootstrap over case indices with `random.Random(seed)`; `compare` resamples the paired deltas over shared ids where neither row is truncated; better when L > 0, worse when U < 0. Cohen's kappa = (po - pe) / (1 - pe), with kappa 1.00 when pe = 1 and po = 1. Numbers print to three places, kappa to two, deltas signed.

- [ ] **Step 4: Run the test**

Run: `bash tests/unit/eval_stats.sh`
Expected: PASS.

- [ ] **Step 5: Wire it into the skill and the gateway**

`llm-eval/SKILL.md`: step 3 says a judge grader is used by the gate only after `agree` prints `calibrated` on at least 30 person-labelled items; step 4 says the harness takes `--model <id>`, sets `LLM_ALLOW_MODEL_OVERRIDE=1` for its own process and writes the results row schema above; step 5 prints `summary` and `compare` against the baseline; step 6 `gate.yaml` gains `method: paired` (default from 30 cases; fail on `worse`) or `method: delta` (below 30, the existing 0.02). Grant `Bash(python3 *skills/llm-eval/scripts/eval_stats.py*)`. Move rubric and judge-bias prose into `references/eval-methods.md` (position, verbosity and self-preference bias with their controls; noise floor; contamination; when pairwise beats pointwise) so `SKILL.md` stays at most 200 lines. Gateway templates: `model_override` checked before the kill switch's network call path, recorded in accounting as `override: true`; a test name `test_model_override_refused_without_flag` in the template's test list. `evals/llm-eval/evals.json` case 3: two recorded runs of a 40-case fixture whose means differ by 0.01; expectation "reports no difference from the paired interval and does not accept a new baseline".

- [ ] **Step 6: Run the gate**

Run: `make docs && make check`
Expected: `check: passed`; `lint-tools` counts the new grant.

- [ ] **Step 7: Commit**

```bash
git add -A plugins/bearing-genai tests/unit/eval_stats.sh evals/llm-eval docs site/src/data devguide/src/data
git commit -m "feat: llm-eval intervals, paired comparison and judge calibration"
```

---

### Task 5: `model-routing` and `route_frontier.py`

**Files:**
- Create: `plugins/bearing-genai/skills/model-routing/SKILL.md`, `.../references/strategies.md`, `.../scripts/route_frontier.py`, `tests/unit/route_frontier.sh`, `evals/model-routing/evals.json`, `evals/model-routing/files/ticket-router/` (fixture repo)
- Modify: `plugins/bearing-genai/skills/llm-gateway/templates/{routing.yaml,gateway-python.md,gateway-typescript.md}` (cascade), `plugins/bearing-genai/README.md`, `evals/triggers.json`, `bin/gen-guide.py` (CATEGORY `genai`, STAGES row), `plugins/bearing/skills/workflow/SKILL.md:58`

**Interfaces:**
- Consumes: results row schema and `eval_stats` bootstrap behaviour (Task 4); the resolver owner entry (Task 1).
- Produces: `python3 route_frontier.py --threshold <x> <results.jsonl>... [--resamples 2000] [--seed 7] [--max-truncated 0.05]`. One line per option `option <name>: n N, mean M, lower L, $C per 1k, p95 P ms, truncated T[, escalated E%]`, then `route-frontier: K options (J cascades), N rows, chose <name> (lower L >= X, $C per 1k)` exit 0, or `... none meets threshold X` exit 1. Cascade name `cascade <small>-><large>`. Exit 2: no files, zero rows, a file with more than one `model` (`<file> holds models a, b: a fallback ran during the eval; re-run it`), a row with `cost_usd` null (`no price for <model>`). When no small-model row carries `valid`, print `cascade: not simulated (no deterministic validity in the results)`.
- Produces, `routing.yaml` route fields: `strategy: static|cascade`, `cascade: {first: <model>, then: <model>}`, `escalate_on: [invalid, refusal, max_tokens]`, `budget_usd_month: <n>`; metric `llm_escalation_total{feature}`.

- [ ] **Step 1: Write the failing test `tests/unit/route_frontier.sh`**

Fixture writer `cand <file> <model> <cost> <latency> <score,valid ...>` over ids c1..c40.

```bash
t_begin "cheapest passing static candidate wins"
# haiku: mean 0.70, $0.20/1k; sonnet: mean 0.95, $1.00/1k; opus: mean 0.97, $3.00/1k
assert_exit 0 python3 "$RF" --threshold 0.85 "$d/haiku.jsonl" "$d/sonnet.jsonl" "$d/opus.jsonl"
assert_contains "$T_OUT" "chose claude-sonnet-5-5"
t_end
t_begin "a cascade that escalates only the invalid cases beats the static choice"
# haiku valid on 30 of 40 with score 1 there, invalid (score 0) on 10; sonnet scores 1 on all 40
assert_exit 0 python3 "$RF" --threshold 0.85 "$d/haiku-v.jsonl" "$d/sonnet.jsonl"
assert_contains "$T_OUT" "option cascade claude-haiku-4-5-20251001->claude-sonnet-5-5"
assert_contains "$T_OUT" "escalated 25.0%"
assert_contains "$T_OUT" "chose cascade claude-haiku-4-5-20251001->claude-sonnet-5-5"
t_end
t_begin "nothing passes: exit 1"
assert_exit 1 python3 "$RF" --threshold 0.99 "$d/haiku.jsonl"; assert_contains "$T_OUT" "none meets threshold 0.99"
t_end
t_begin "mixed models"
assert_exit 2 python3 "$RF" --threshold 0.5 "$d/mixed.jsonl"; assert_contains "$T_OUT" "a fallback ran during the eval"
t_end
t_begin "no price"
assert_exit 2 python3 "$RF" --threshold 0.5 "$d/noprice.jsonl"; assert_contains "$T_OUT" "no price for"
t_end
t_begin "no files and empty files exit 2"
assert_exit 2 python3 "$RF" --threshold 0.5; : > "$d/e.jsonl"; assert_exit 2 python3 "$RF" --threshold 0.5 "$d/e.jsonl"
assert_contains "$T_OUT" "nothing checked"
t_end
t_begin "no validity field: static only, said so"
assert_exit 0 python3 "$RF" --threshold 0.85 "$d/haiku.jsonl" "$d/sonnet.jsonl"; assert_contains "$T_OUT" "cascade: not simulated"
t_end
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/unit/route_frontier.sh`
Expected: FAIL, script not found.

- [ ] **Step 3: Implement `route_frontier.py`**

Per candidate: mean over non-truncated rows, lower bound from a percentile bootstrap (same method as `eval_stats.py`; copy the 15-line function, plugins do not import from each other's skills), cost per 1k = mean `cost_usd` over all rows x 1000, p95 by nearest rank. Cascade for each pair with cheaper first and every first-model row carrying `valid`, over shared ids: valid case takes the small row's score, cost and latency; invalid takes the large row's score, both costs and both latencies. Eligible: lower >= threshold and truncated share <= `--max-truncated`. Choose minimum cost, then minimum p95.

- [ ] **Step 4: Run the test**

Run: `bash tests/unit/route_frontier.sh`
Expected: PASS.

- [ ] **Step 5: Write the skill**

`SKILL.md` (at most 200 lines): frontmatter `name: model-routing`, description such as `'Picks the cheapest model or cascade per LLM feature that still passes its eval, from measured scores and costs, any provider. Use when asked "which model should this feature use" or "cut our LLM bill".'`, argument-hint `"<feature|all> [--threshold <x>] [--candidates <id,...>]"`, allowed-tools `Read, Write, Edit, Grep, Glob, Skill, AskUserQuestion, Bash(ls:*), Bash(make eval:*), Bash(uv run python evals/*), Bash(npx tsx@4.23.15 evals/*), Bash(python3 *skills/model-routing/scripts/route_frontier.py*), Bash(python3 *skills/llm-gateway/scripts/llm_callsites_check.py*)`. Steps 1 to 6 of spec section D; Decisions first on `bearing:tech-decision` key llm provider and models; the missing-price question by AskUserQuestion per the bearing plugin's `references/console.md` (options: "paste the price and its source", "leave this candidate out"); the classifier strategy and cascade cost arithmetic in `references/strategies.md`. Output contract:

```
## Model routing: <feature>
candidates: <K> (<ids>), golden set <N> cases (<full | minimal>)
<route_frontier.py option lines, verbatim>
chosen: <name>, lower <L> >= threshold <X>, $<C> per 1k, p95 <P> ms
route: llm/routing.yaml routes.<feature> strategy <static|cascade>, budget $<B>/month, alert at 80%
monthly estimate: $<M> at <V> requests/day (was $<W>)
re-run: when a model id or price changes, or by <date + 90 days>
report: docs/genai/routing.md
```

Gotchas: a fallback during an eval run invalidates the candidate; price rows carry source and date; Haiku 4.5 has no `effort`; a cascade's p95 is the escalated path's; never route on a `minimal` set without saying provisional. Gateway templates: the `cascade` branch calls `then` once when the first answer fails `escalate_on`, counts `llm_escalation_total`, accounts both calls. `gen-guide.py`: `model-routing` in CATEGORY `genai`; STAGES "GenAI features" row `("Cheapest model that passes", "model-routing", "bearing-genai", "frontier of score and cost per candidate, cascade, budget and alert")`. `workflow/SKILL.md` GenAI row adds `bearing-genai:model-routing`. Triggers: should rows such as "the triage feature runs on the big model and costs us 4k a month, can a cheaper one do it" and "compare haiku sonnet and a gpt model on our extraction eval and set the route"; near misses expecting `llm-gateway` ("put all our model calls behind one module with retries") and `llm-eval` ("build a golden set for the summariser"). Evals case 1 on `files/ticket-router` (three recorded result files built so the cascade wins, threshold 0.85 in `docs/genai/triage-solution.md`): expectations "runs route_frontier.py on the three files", "chooses the cascade from the frontier line", "writes strategy cascade with escalate_on and a budget to llm/routing.yaml", "does not quote a price from memory". Case 2: one result file holds two models; expectation "refuses the candidate and asks for a re-run".

- [ ] **Step 6: Run the gate**

Run: `make docs && make check`
Expected: `check: passed`; `lint-skills` shows `bearing-genai=13`; `lint-triggers` and `lint-evals` count the new skill.

- [ ] **Step 7: Commit**

```bash
git add -A plugins/bearing-genai plugins/bearing/skills/workflow tests/unit/route_frontier.sh evals bin/gen-guide.py docs site/src/data devguide/src/data
git commit -m "feat: model-routing picks the cheapest passing model or cascade"
```

---

### Task 6: `dataset-generation` and `dataset_check.py`

**Files:**
- Create: `plugins/bearing-genai/skills/dataset-generation/SKILL.md`, `.../references/generation.md`, `.../templates/DATASHEET.md`, `.../scripts/dataset_check.py`, `tests/unit/dataset_check.sh`, `evals/dataset-generation/evals.json`, `evals/dataset-generation/files/{short-seed,intake-notes}/`
- Modify: `plugins/bearing-genai/skills/llm-fine-tuning/SKILL.md` (data step hands generation to `dataset-generation`), `plugins/bearing-genai/README.md`, `evals/triggers.json`, `bin/gen-guide.py`

**Interfaces:**
- Consumes: results and cases schema (`evals/<name>/cases.jsonl` rows carry `id` and `input`).
- Produces: `python3 dataset_check.py <rows.jsonl> --kind eval|train|preference [--against <cases.jsonl>] [--taxonomy <taxonomy.json>] [--audit <audit.jsonl>] [--near 0.8] [--max-near 0.02]`. Row: `{"id", "input": str, "source": "real|owner|synthetic", "cell": {dim: value}}` plus `expected` (eval), `output` (train), `chosen` and `rejected` (preference). Taxonomy: `{"dimensions": {dim: [values]}}`. Audit row: `{"id", "verdict": "accept|reject", "by"}`. Prints `dataset-check: R rows (real a, owner b, synthetic c), cells F of Y filled (E empty), exact duplicates D, near duplicates N, contaminated K against M cases, audited U of Q required (accepted P%)`, then `dataset-check: passed` exit 0 or `dataset-check: X problems` exit 1 with one line per problem. Exit 2 `nothing checked` on zero rows.
- Rules: text compared after lower-casing and collapsing whitespace; near duplicate = character 5-gram Jaccard >= `--near`; above 20,000 rows exact only, printed as `near duplicates: skipped above 20000 rows`; required audit = min(synthetic, max(30, ceil(0.1 x synthetic))); acceptance >= 90%; eval kind: synthetic share of (rows + against) <= 0.5.

- [ ] **Step 1: Write the failing test `tests/unit/dataset_check.sh`**

```bash
t_begin "clean train set passes with every count printed"
assert_exit 0 python3 "$DC" "$d/train.jsonl" --kind train --against "$d/cases.jsonl" --taxonomy "$d/tax.json"
assert_contains "$T_OUT" "dataset-check: 12 rows (real 12, owner 0, synthetic 0), cells 4 of 4 filled (0 empty), exact duplicates 0"
assert_contains "$T_OUT" "dataset-check: passed"
t_end
t_begin "contamination survives normalisation"
# a train row equal to a golden case except case and spacing
assert_exit 1 python3 "$DC" "$d/train-leak.jsonl" --kind train --against "$d/cases.jsonl"
assert_contains "$T_OUT" "contaminated 1 against"
t_end
t_begin "exact duplicate and missing source each fail"
assert_exit 1 python3 "$DC" "$d/dup.jsonl" --kind train; assert_contains "$T_OUT" "exact duplicates 1"
assert_exit 1 python3 "$DC" "$d/nosource.jsonl" --kind train; assert_contains "$T_OUT" "missing source"
t_end
t_begin "synthetic eval rows need an audit of at least 30 and 90% accepted"
assert_exit 1 python3 "$DC" "$d/syn40.jsonl" --kind eval --audit "$d/audit20.jsonl"; assert_contains "$T_OUT" "audited 20 of 30 required"
assert_exit 0 python3 "$DC" "$d/syn40.jsonl" --kind eval --audit "$d/audit30ok.jsonl" --against "$d/cases60.jsonl"
assert_exit 1 python3 "$DC" "$d/syn40.jsonl" --kind eval --audit "$d/audit30bad.jsonl" --against "$d/cases60.jsonl"; assert_contains "$T_OUT" "accepted 80.0%"
t_end
t_begin "synthetic share over half of an eval set fails"
assert_exit 1 python3 "$DC" "$d/syn40.jsonl" --kind eval --audit "$d/audit30ok.jsonl" --against "$d/cases10.jsonl"; assert_contains "$T_OUT" "synthetic share"
t_end
t_begin "empty cells are counted"
assert_exit 0 python3 "$DC" "$d/train-3cells.jsonl" --kind train --taxonomy "$d/tax.json"; assert_contains "$T_OUT" "cells 3 of 4 filled (1 empty)"
t_end
t_begin "zero rows exits 2"
: > "$d/none.jsonl"; assert_exit 2 python3 "$DC" "$d/none.jsonl" --kind train; assert_contains "$T_OUT" "nothing checked"
t_end
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/unit/dataset_check.sh`
Expected: FAIL, script not found.

- [ ] **Step 3: Implement `dataset_check.py`**

Exact duplicates by hash of the normalised `input`; near duplicates over pairs of 5-gram sets; contamination is exact or near match of a row's `input` against any `--against` case `input`, for every kind.

- [ ] **Step 4: Run the test**

Run: `bash tests/unit/dataset_check.sh`
Expected: PASS.

- [ ] **Step 5: Write the skill**

Frontmatter `name: dataset-generation`; description such as `'Generates eval, training or preference data from a real seed: taxonomy, generation, dedupe, contamination check, human audit, datasheet. Use when asked to "make synthetic data" or "we need more examples".'`; argument-hint `"<eval|train|preference> <name> [--seed <path>] [--target N]"`; allowed-tools `Read, Write, Edit, Grep, Glob, Skill, AskUserQuestion, Bash(ls:*), Bash(wc -l:*), Bash(mkdir:*), Bash(uv run python datasets/*), Bash(python3 *skills/dataset-generation/scripts/dataset_check.py*)`. Steps 1 to 7 of spec section E; fewer than 10 seed rows stops with the spec's sentence; the generator-model question by AskUserQuestion per the bearing plugin's `references/console.md`; generation scripts land in `datasets/<name>/generate.py` and call the gateway with a `prompt-registry` prompt; `templates/DATASHEET.md` sections Provenance, Seed and licence, Generation (model ids, prompt versions), Filtering (counts from `dataset_check.py`), Audit, PII, Intended use, each with what goes there. Output contract:

```
## Dataset: <name> (<kind>)
seed: <S> real rows from <path>; taxonomy <D> dimensions, <Y> cells
generated: <G> with <model id> (prompt <name> v<n>); kept <K>
<dataset_check.py count line, verbatim>
audit: <U> of <Q> by <person>, accepted <P>%
written: datasets/<name>/rows.jsonl, DATASHEET.md; promoted to evals/<name>/cases.jsonl: <n> | none
```

`llm-fine-tuning`: its data step names `bearing-genai:dataset-generation` for teacher and synthetic rows and keeps its split and format rules. `gen-guide.py`: CATEGORY and STAGES row `("Data when real data is short", "dataset-generation", "bearing-genai", "taxonomy, generated rows, dedupe and contamination counts, audit, datasheet")`. Triggers: should rows such as "we only have 15 real intake notes, I need a few hundred more varied ones for the classifier eval" and "make preference pairs for DPO from our support replies"; near misses expecting `llm-eval` ("score the new prompt against our labelled tickets") and `tabular-ml` ("forecast next month's bookings"). Evals case 1 on `files/short-seed` (6 real rows): expectation "stops and asks for at least 10 real rows; generates nothing". Case 2 on `files/intake-notes` (40 real rows, a golden set, `llm/routing.yaml` naming the model under test): expectations "chooses a generator other than the model under test", "runs dataset_check.py with --against the golden set", "writes DATASHEET.md with the audit counts", "does not promote unaudited rows".

- [ ] **Step 6: Run the gate**

Run: `make docs && make check`
Expected: `check: passed`; `lint-skills` shows `bearing-genai=14`.

- [ ] **Step 7: Commit**

```bash
git add -A plugins/bearing-genai tests/unit/dataset_check.sh evals bin/gen-guide.py docs site/src/data devguide/src/data
git commit -m "feat: dataset-generation with a contamination and audit gate"
```

---

### Task 7: The GenAI flow

**Files:**
- Modify: `docs/flows.json` (`_about`, new flow, the two "Calls to a model" options), `bin/gen-guide.py` (`from` column `bearing-genai` on every GenAI STAGES row), `plugins/bearing/bin/brg-session` (`next-step`), `site/src/lib/nav.ts:7`, `site/src/pages/Home.tsx:5`
- Test: `tests/unit/session_resume.sh`

**Interfaces:**
- Consumes: skill names from Tasks 1, 5, 6.
- Produces: flow id `genai`; `plugins/bearing/bin/flow-steps.tsv` rows `genai<TAB>n<TAB>skill` (generated); `brg-session next-step` uses flow `genai` when the branch is not a bugfix branch and its timeline holds `genai-design`.

- [ ] **Step 1: Write the failing test in `tests/unit/session_resume.sh`**

```bash
t_begin "a branch that ran genai-design follows the genai flow"
git -C "$repo" checkout -q -b feat/TASK-40-genai
ran "bearing-genai:genai-design"
assert_exit 0 in_repo next-step
assert_eq "$(step genai 3)" "$T_OUT"
assert_eq "tech-decision" "$(step genai 3)" "genai step 3"
t_end
t_begin "a bugfix branch stays on the bugfix flow after genai-design"
git -C "$repo" checkout -q -b bugfix/TASK-41-g
ran "bearing-genai:genai-design"
assert_exit 0 in_repo next-step
assert_eq "$(step bugfix 1)" "$T_OUT"
t_end
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/unit/session_resume.sh`
Expected: FAIL, `step genai 3` is empty.

- [ ] **Step 3: Add the flow**

A fifth entry in `flows`, after `feature`: id `genai`, title "GenAI feature or product", tagline "From a problem a model should solve to a measured, routed, guarded release.", when "Anything whose behaviour comes from a model: retrieval, agents, tools for models, speech, vision, tabular ML, training." Steps in this order (`pack` `bearing-genai` unless marked; each with title, does, output, why in the house style, no ranking words):

```
phase Frame
step g-task start-task (bearing)
step g-design genai-design
branch "Is a provider, model or store still open?"  Yes: step g-decide tech-decision (bearing) | No: []
phase Set the bar
branch "Is there enough real data for a golden set?"  No: step g-data dataset-generation | Yes: []
step g-eval llm-eval
phase Build
branch "What is being built?"
  Retrieval: g-rag rag | An agent: g-agent llm-agent | Tools for models: g-mcp mcp-server
  Speech or voice: g-speech speech | Vision: g-vision computer-vision
  Tabular ML: g-tabular tabular-ml | Training an open model: g-train llm-fine-tuning
step g-prompts prompt-registry
phase Every call
step g-gateway llm-gateway
step g-route model-routing
phase Prove it
step g-guard llm-guardrails
step g-gate llm-eval        (the gate run against the baseline)
step g-dod definition-of-done (bearing)
step g-review branch-review (bearing)
step g-mr merge-request (bearing)
```

`_about` says five task flows. In greenfield and feature, find the option labelled "Calls to a model" (by label, not position: sub-project 2 reorders greenfield), set `pack` to `bearing-genai` on its three steps, and append `{"kind": "link", "title": "Build the model part with the GenAI flow", "flow": "genai"}`. `nav.ts` and `Home.tsx` colour maps gain `genai: "var(--ok)"` (**author's call**: reuse an existing token; the site build defines no fifth).

- [ ] **Step 4: Make `next-step` follow it**

In `brg-session` `next-step`, after `done_list` is computed: `[ "$flow" = feature ] && printf '%s\n' "$done_list" | grep -qx 'genai-design' && flow=genai`.

- [ ] **Step 5: Run the tests and the gate**

Run: `make docs && bash tests/unit/session_resume.sh && make check`
Expected: PASS; `site data: <n> skills, 5 flows (...)`; `gen-flow-steps: 5 flows`; `check: passed`.

- [ ] **Step 6: Commit**

```bash
git add -A docs/flows.json bin/gen-guide.py plugins/bearing/bin tests/unit/session_resume.sh site devguide/src/data docs
git commit -m "feat: a GenAI flow, linked from greenfield and feature"
```

---

### Task 8: Version 0.9.0 and the changelog

**Files:**
- Modify: `VERSION`, `.claude-plugin/marketplace.json` (metadata and four entries), `plugins/*/.claude-plugin/plugin.json` (four), `CHANGELOG.md`

- [ ] **Step 1: Bump and record**

`VERSION` and every version field to `0.9.0`. CHANGELOG: move `[Unreleased]` content under `## [0.9.0] - <date of the commit>` with an Added list (the bearing-genai plugin; model-routing; dataset-generation; llm-eval intervals, paired gate and judge calibration; the GenAI flow; lint-model-ids) and a Changed list (12 skills moved, call them as `bearing-genai:<name>` or by bare name; current model ids; `profile --llm yes` needs bearing-genai).

- [ ] **Step 2: Run the gate**

Run: `make docs && make check`
Expected: `lint-version: 9 fields match VERSION 0.9.0 (4 plugins, 4 marketplace entries)`; `check: passed`.

- [ ] **Step 3: Commit and print the push command, not run**

```bash
git add -A VERSION .claude-plugin plugins CHANGELOG.md docs site/src/data devguide/src/data
git commit -m "chore: release 0.9.0"
echo "When you are ready: make gate && git push -u origin feat/GenAIPack"
```

---

## Later phases (separate plans, from spec section G)

- Phase 2, conversations: `chatbot` (web, Slack, Teams, WhatsApp, Telegram, Discord), `voice-agent`, `llm-eval --task conversation` with a simulated user; flow options "Chatbot or bot" and "Voice agent".
- Phase 3, breadth: `llm-agent --framework` with templates per framework and a tech-decision key; RAG per-type references and `llm-eval --task rag-answer`; `model-training`; remote MCP with OAuth and the client side; online evals.
