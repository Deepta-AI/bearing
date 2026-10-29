---
name: dataset-generation
description: 'Generates eval, training or preference data from a real seed, deduped and audited. Use when asked to "make synthetic data" or "we need more examples".'
argument-hint: "<eval|train|preference> <name> [--seed <path>] [--target N] [--unattended]"
allowed-tools: Read, Write, Edit, Grep, Glob, Skill, AskUserQuestion, Bash(ls:*), Bash(wc -l:*), Bash(mkdir:*), Bash(uv run python datasets/*), Bash(python3 *skills/dataset-generation/scripts/dataset_check.py*), Bash(printenv BEARING_AUTOPILOT BEARING_NONINTERACTIVE)
---

# dataset-generation

Synthetic rows are cheap and easy to fool yourself with. This skill grows
a real seed into more rows along the dimensions that matter, removes
duplicates and anything that leaks the golden set, and has a person audit
a sample before a row counts. `scripts/dataset_check.py` is the gate.

## Inputs

- Kind and name: `$1` (`eval`, `train` or `preference`) and `$2`.
- Seed: `--seed <path>`, else the rows of `evals/<name>/cases.jsonl`
  whose `source` is not synthetic, else `datasets/<name>/seed.jsonl`.
  Row shapes are the ones `llm-eval` and `llm-fine-tuning` write: `input`
  a string or an object, or chat `messages`; any `source` string.
- Cells: `docs/genai/<name>-solution.md` (inputs, users, languages, edge
  cases) and the three worst cases in `docs/genai/evals.md`.
- Model under test and candidate generators: `llm/routing.yaml`
  (`routes.<name>` and the `models:` table); eval scores per model from
  `docs/genai/evals.md` for choosing a teacher.
- Golden set to check against: `evals/<name>/cases.jsonl` from
  `bearing-genai:llm-eval`, which comes first in the GenAI flow; required
  for `train` and `preference`.
- Methods, prompts and the audit sample: `references/generation.md`.
- Unattended: `--unattended`, or
  `printenv BEARING_AUTOPILOT BEARING_NONINTERACTIVE` prints a value
  other than `0`. The skill then asks nothing: the generator takes the
  recommended default from step 3 when one exists; rows are generated,
  filtered and the audit sample drawn, but nothing is promoted or handed
  to training, because the audit is a person's step. It stops with one
  line, `dataset-generation: unattended, missing:` then the list
  (generator for <name>, person audit of Q rows, seed rows N of 10,
  golden set for <name> when the kind is train or preference).

## Steps

1. Seed. Count it:
   `python3 "${CLAUDE_PLUGIN_ROOT}/skills/dataset-generation/scripts/dataset_check.py" <seed> --kind <kind>`
   and read real plus owner from its count line (problems it lists for
   the seed, such as no `--against`, do not matter here). Fewer than 10 stops the
   skill with "synthetic data with no real seed measures the generator;
   give me at least 10 real rows" and generates nothing. Seed rows with
   PII are cleaned first (`bearing:privacy-review` names the fields).
2. Taxonomy in `datasets/<name>/taxonomy.json`,
   `{"dimensions": {dim: [values]}}`: the dimensions that matter (intent,
   difficulty, language including code-mixed, length, edge case,
   adversarial), values from the solution doc and the worst cases. Keep
   it to what the product sees; every cell needs a reason. Target per
   cell from `--target` (default: the larger of 100 and 5 times the seed)
   divided by the cells, more for the worst cases' cells.
3. Generator. For `eval` rows, a model of a different family or tier
   from the model under test (`routes.<name>` in `llm/routing.yaml`); for
   `train` and `preference`, a teacher whose eval score in
   `docs/genai/evals.md` beats the model being trained. Ask with
   AskUserQuestion (as the bearing plugin's `references/console.md`
   says), options "<the strongest `models:` key that is not the model
   under test> (Recommended)" (for train: the teacher with the best
   accepted score), "another key from `models:`" and "I will paste rows
   written by people instead". Never the model under test for eval rows:
   it grades its own phrasing as easy. Unattended: the recommended key,
   else stop as Inputs says. Model ids come from the `claude-api` skill.
4. Generate. `datasets/<name>/generate.py` from
   `references/generation.md`: a versioned prompt from
   `bearing-genai:prompt-registry` (`<name>-generate` v1, a new version
   for every change), one call per cell batch through the gateway
   (`llm/`) on a `dataset-<name>` route set to the generator, seed rows
   rotated as examples, each row written with `source: synthetic`, its
   `cell`, the `expected` or `rubric` the generator proposes for eval
   rows (the audit checks it), and the model id from the response and the prompt version in
   `meta`. Run it: `uv run python datasets/<name>/generate.py --target <N>`.
   It writes `datasets/<name>/generated.jsonl` and prints its count.
5. Filter. Run
   `python3 "${CLAUDE_PLUGIN_ROOT}/skills/dataset-generation/scripts/dataset_check.py" datasets/<name>/generated.jsonl --kind <kind> --against evals/<name>/cases.jsonl --taxonomy datasets/<name>/taxonomy.json`.
   No `evals/<name>/cases.jsonl` yet: kind `eval` leaves `--against` out
   (it is growing the first golden set from the seed); `train` and
   `preference` stop with "run `bearing-genai:llm-eval` first: training
   rows are checked against the golden set" (the gate prints
   `contamination: 0 cases checked` without it). Drop every row it names (exact or near duplicate at 5-gram Jaccard
   0.8, contaminated, missing a field) into `datasets/<name>/rows.jsonl`
   and run it again on that file until only the audit problem is left.
   Zero contamination is allowed for every kind: a train row that matches
   a golden case grades the model on its own training, an eval row that
   repeats one adds nothing. Empty cells go back to step 4 once; still
   empty, the report names them.
6. Audit. Draw the sample in `references/generation.md` (the gate's
   required count, capped at the synthetic rows: for kind `eval`, 20
   percent or 30 rows, whichever is larger, `llm-eval`'s labelling rule;
   for `train` and `preference`, 10 percent or 30) into
   `datasets/<name>/audit-sample.jsonl`. A person writes
   `datasets/<name>/audit.jsonl`, one row per checked row with `id`,
   `verdict` (`accept` or `reject`), `by` and `why`; the skill never
   writes a verdict. Then run step
   5's command on `rows.jsonl` with `--audit datasets/<name>/audit.jsonl`.
   Acceptance below 90 percent sends the batch back to step 4 with the
   rejection reasons in a new prompt version.
7. Use and record. `datasets/<name>/DATASHEET.md` from
   `templates/DATASHEET.md`, every section filled, the filtering counts
   copied from the gate. Then by kind:
   - `eval`: on `dataset-check: passed`, append the batch less its
     rejected rows to `evals/<name>/cases.jsonl` with `source: synthetic`, `labelled_by`
     the auditor and `labelled_at`. The gate already holds synthetic rows
     to at most half of rows plus golden set; rows over that wait.
   - `train`, `preference`: hand `rows.jsonl` to
     `bearing-genai:llm-fine-tuning` step 3, which splits and formats it.
   Print the contract.

## Output contract

```
## Dataset: <name> (<kind>)
seed: <S> real rows from <path>; taxonomy <D> dimensions, <Y> cells
generated: <G> with <model id> (prompt <name> v<n>); kept <K>
<dataset_check.py count line, verbatim>
audit: <U> of <Q> by <person>, accepted <P>%
written: datasets/<name>/rows.jsonl, DATASHEET.md; promoted to evals/<name>/cases.jsonl: <n> | none
```

Stopped early: the contract's first line, then the stop line (seed rows
N of 10, or the unattended `missing:` list) in place of the rest.

## Gotchas

- Synthetic data with no real seed measures the generator, not the
  product. The seed rule is not negotiable.
- The model under test generating its own eval rows writes cases it
  finds easy. A different family or tier generates; a person audits.
- Contamination hides behind shape. A chat row and an object case with
  the same words are the same case; so is a row that repeats one field
  of a case, or wraps it ("Classify: <case text>"). The gate checks
  each form.
- One threshold (0.8) for near duplicates, contamination and
  containment. `llm-fine-tuning` uses this gate instead of its own.
- Never run `--against` the file the rows were drawn from, such as the
  step 1 seed check against its own `cases.jsonl`: every row matches
  itself, so all read as contaminated and the count says nothing. Step
  1 runs without `--against`; steps 5 and 6 check generated rows
  against the golden set.
- A filled taxonomy is not a varied one. Read 20 rows of the biggest
  cell; templated phrasing shows there first.
- Unaudited synthetic rows never join a golden set and never train a
  model, in any mode.
- Generating from customer data needs the consent the seed had, and a
  teacher's outputs used for training need the provider's usage policy
  checked (`llm-fine-tuning` records it in its ADR).
- Above 20,000 rows the gate checks exact duplicates only and says so;
  dedupe a batch that size per cell first.
