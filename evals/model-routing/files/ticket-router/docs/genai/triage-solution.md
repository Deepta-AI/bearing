# Triage: solution

## Task

Classify one ticket into one of six queues. Output: JSON
`{"queue": <label>}` with a label from the closed set.

## Acceptance

- Accuracy on the labelled triage set: the lower bound of the 95% interval
  at or above **0.85**.
- p95 latency under 3 seconds.

## Volume and cost

About 20,000 calls a day. Finance asked for the triage line of the model
bill to come down without the accuracy bar moving.

## Evaluation

`evals/triage/`, graded by exact match on the queue label after
lower-casing and trimming.
