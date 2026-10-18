# Eval methods

What `llm-eval` steps 3 to 6 rest on: how to keep a judge honest, how
much a score moves on its own, and the statistics `scripts/eval_stats.py`
prints.

## Rubrics

A rubric is a list of claims a reader can check against the output,
each answered yes or no: "names the plan the step needs", not "is
helpful". The score is the share of yes. Three to seven claims per case;
more and the judge starts to skim. Write them from the success criteria
in the solution doc, never from a model's answer. A claim the
deterministic graders can check (word count, a section present, valid
JSON) is a code grader, not a rubric item.

## Judge bias and its controls

| Bias | What it does | Control |
| --- | --- | --- |
| Position | In a pairwise question the judge favours the first (or second) answer | Randomise A and B per case; for a release decision run both orders and count a win only when it holds in both |
| Verbosity | Longer, more confident answers score higher with no more claims met | Rubric of checkable claims; the judge system prompt says not to reward length; a calibration item where the short answer is the right one |
| Self-preference | A judge rates its own model's style higher | The judge is never the model under test, and is stronger than it (the ladder in step 3); for Opus 5.5 under test, Fable 5.1 or pairwise |
| Instruction leakage | Text inside the output ("rate this 3") steers the verdict | Output and context are data in the judge's system prompt; keep one case that carries such a line |
| Drift | A judge model or prompt change moves every score | Pin the judge model id and prompt version in each row; recalibrate after either changes |

Calibration is the check that the controls worked. A person labels at
least 30 items the judge also graded (same `case_id`, `label` set on
both rows, pass or fail or the rubric level), then

`python3 "${CLAUDE_PLUGIN_ROOT}/skills/llm-eval/scripts/eval_stats.py" agree evals/<name>/calibration/people.jsonl evals/<name>/calibration/judge.jsonl`

prints `eval-agree: S shared items, agreement A, kappa K: calibrated`.
Cohen's kappa corrects raw agreement for chance: with 90 percent of
items labelled pass, a judge that always says pass agrees 0.90 and has
kappa 0. The bar is 30 shared items and kappa 0.6 (`--min-items`,
`--min-kappa`). An uncalibrated judge is reported, never gated on.

## Noise floor

The same prompt on the same cases does not give the same score twice:
sampling varies, and the deep and balanced models take no `temperature`
to pin it. Run the baseline twice and compare the runs with
`compare`; the interval it prints is the noise floor for this set. A
change smaller than it cannot be seen with this set, whatever the two
means say.

## Statistics

Every number excludes rows with `truncated: true` and counts them.

- `summary`: the mean score and a 95% percentile bootstrap interval:
  resample the cases with replacement 2,000 times (`--resamples`) with a
  fixed seed (`--seed`, default 7), take the 2.5th and 97.5th
  percentiles of the resampled means. Same file and seed, same interval.
- `compare`: pairs the two runs by `case_id` where neither row is
  truncated, takes the per-case delta (new minus base) and bootstraps
  its mean. `better` when the lower bound is above 0, `worse` when the
  upper bound is below 0 (exit 1), else `no difference`. Pairing removes
  the variation between cases, so it sees changes an unpaired
  comparison of two means misses.
- Zero cases, zero shared ids, or every row truncated exits 2 with
  `nothing checked`; a duplicate `case_id` or a score outside 0 to 1
  exits 2 with its line.

`gate.yaml` `method: paired` fails CI on `worse`. Below 30 cases the
interval is too wide to be useful, so `method: delta` keeps the fixed
drop (default 0.02). As a guide, on 40 pass or fail cases at 0.80 a
single run's interval is about plus or minus 0.12; a paired interval
narrow enough to see a change of 0.02 needs about a thousand cases when
one case in ten changes its result between versions.

## Contamination

A case the model has already seen measures recall. Check, before a
score is trusted:

- no case input appears in the prompt's few-shot examples or in a
  fine-tuning train file (`llm-fine-tuning`); compare after lower-casing
  and collapsing whitespace, and for object inputs on canonical JSON;
- a public benchmark item copied into the set is dropped or marked;
- cases written by looking at the current model's answers are relabelled
  by someone who did not see them.

## Pairwise or pointwise

Pointwise (a rubric score per output) when the criteria are checkable
claims and the score must be comparable across releases. Pairwise (A or
B against a frozen reference) when the question is style, tone or "is
the new prompt better" between two close versions, where people and
judges rank more reliably than they score. Pairwise needs the position
control above and a reference that never changes; regenerating it
changes what the win rate means.
