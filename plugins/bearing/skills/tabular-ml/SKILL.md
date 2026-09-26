---
name: tabular-ml
description: 'Builds classical ML on tabular or event data (churn, scoring, forecasts, anomalies) with leak-proof splits, a baseline, calibration, drift checks. Use when asked to "predict churn", "forecast demand" or "train a model".'
argument-hint: "<classify|regress|forecast|anomaly|rank> <name> [--data <path>]"
allowed-tools: Read, Write, Edit, Grep, Glob, Skill, Bash(ls:*), Bash(wc -l:*), Bash(make:*), Bash(git status:*), Bash(uv run:*), Bash(python3 *skills/tabular-ml/scripts/split_check.py*), Bash(python3 *skills/tabular-ml/scripts/baseline_gate.py*)
---

# tabular-ml

Most ML that fails in production failed at the split: the model saw the
future, or the same customer on both sides, and the score was a leak. The
rest failed because nobody asked whether a one-line rule did as well.
This skill frames the prediction, proves the split cannot leak, makes a
baseline the model must beat, and ships the model with its version,
explanation and drift check.

Not this: LLM features are `llm-eval` and `genai-design`; the
pipelines that feed the features (dbt, Airflow) are `bearing-backend:data-pipeline`; A/B
analysis of a model's effect is `ab-experiment`.

## Inputs

- Task and name: `$1` and `$2`; if absent, asks what is predicted, for
  whom, when the prediction is made and what action follows, in one
  question.
- Data: `--data`, else `data/<name>/` or the warehouse tables the user
  names; if none, the plan names the tables and the build stops with
  zero rows reported.
- Stack: `pyproject.toml` (uv, pytest); if absent, a `uv` project is
  created under `ml/<name>/`.
- Solution doc: `docs/genai/<name>-solution.md` or `docs/ml/<name>.md`
  for the metric and the cost of errors; if absent, step 1 writes
  `docs/ml/<name>.md`.
- Method reference: `references/methods.md` in this skill.

## Steps

**Decisions first.** Before building, run `tech-decision` for the key ml
model family and serving. `tech-decision` asks only about keys no accepted
ADR, the request or the code already settles, one question at a time,
and records only what the user decides.

1. Framing in `docs/ml/<name>.md`: the unit (user, account, series), the
   prediction time, the label and its window (for example no session in
   the 14 days after the prediction time), the action taken on a
   prediction, the metric that matches the action (precision at the top
   k for a campaign, MAE for a forecast, recall at a false-alarm rate for
   alerts) and the cost of each error.
2. Features built as of the prediction time only: every feature query
   takes `as_of` and reads nothing after it. Point-in-time joins, never
   the latest row. Write the feature list with the reason per feature.
3. Split by time (train on earlier, test on later), and by group when
   one unit appears many times. Prove it:
   `python3 "${CLAUDE_PLUGIN_ROOT}/skills/tabular-ml/scripts/split_check.py" --train <f> --valid <f> --test <f> --time <col> --group <col> --target <col>`.
   Copy its `ml-split:` line. A problem stops the build until fixed.
4. Baseline: the rule a person would write (recency for churn, last
   week same hour for a forecast, a rolling mean with a band for
   anomalies), scored on the test split. Then the model from
   `references/methods.md` (gradient-boosted trees by default for
   tabular; a seasonal model for series), tuned on validation only.
5. Gate: write `ml/<name>/metrics.json` with both blocks and run
   `python3 "${CLAUDE_PLUGIN_ROOT}/skills/tabular-ml/scripts/baseline_gate.py" ml/<name>/metrics.json --metric <m> --min-lift <noise>`.
   The noise floor comes from repeating the baseline on bootstrapped
   test samples. A model that fails the gate does not ship; the
   baseline does.
6. Calibration and explanation: a calibration curve and the Brier score
   for probabilities (isotonic or Platt on validation when off); global
   drivers and per-prediction reasons (SHAP for trees), turned into
   plain words for the people who act on them.
7. Registry and serving: one entry per trained model (data window,
   features, metrics, baseline, who promoted it) in
   `ml/<name>/registry.jsonl`; batch scoring on a schedule unless a user
   waits on the answer; every score stores the model version.
8. Monitoring: input drift per feature (population stability index,
   alert above 0.2), prediction distribution, and the realised metric
   once labels arrive, with the retraining trigger written down.
9. Print the contract.

## Output contract

```
## ML: <name> (<task>)
framing: docs/ml/<name>.md, unit <u>, predicted at <t>, label window <w>
data: <rows> rows, <features> features, as-of joins: yes
split: <ml-split line, verbatim>
baseline: <metric> <b> (<rule>)
model: <metric> <m> (<family>), <ml-baseline line, verbatim>
calibration: Brier <x> | not a probability task
explanations: top drivers <a, b, c>
registry: ml/<name>/registry.jsonl entry <id>, serving <batch | service>
monitoring: PSI per feature, realised metric <when>, retrain on <trigger>
```

## Gotchas

- Run the kit's scripts from the kit path while working. When the repo
  wants a make target or CI job for a check, copy the script into the
  repo's `scripts/` and point the target there; a target that names the
  kit's own path breaks on every other machine.
- A feature computed with data after the prediction time is a leak even
  when it looks innocent (total purchases, last login, account status).
  The `as_of` parameter is the fix, not a review note.
- Random row splits on event data put the same user in train and test.
  The model memorises users and the score collapses in production.
- A model that does not beat the rule by more than the noise floor is
  cost with no benefit. Ship the rule and say so.
- An anomaly detector judged on precision alone gets muted within a week
  when it pages on every festival spike. Include known seasonal events
  in the evaluation and count false alarms per week.
- SHAP explains the model, not the world. "Drivers" are associations; do
  not present them as causes to act on without an experiment.
