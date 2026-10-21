# help-answers

Answers customer questions from the help centre articles. The prompt lives
in `answers/prompt.py` in the service repository; this folder holds only
its eval.

## Eval

- `evals/answers/cases.jsonl`: 40 real questions, each with a five-item
  rubric written by the support lead.
- `evals/answers/results/<version>.jsonl`: one row per case from
  `make eval EVAL=answers` (score is the share of rubric items met).
- `evals/answers/results/<version>.summary.json`: the run summary. The
  baseline is the last summary with `accepted: true`.
- `evals/answers/gate.yaml`: the CI gate.

v2 is the accepted baseline (0.800). v3 of the prompt ran in CI on
2026-10-14 and scored 0.810. There is no API key on laptops; the two
recorded runs are all there is.
