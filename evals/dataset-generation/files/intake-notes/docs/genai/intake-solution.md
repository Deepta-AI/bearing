# Intake: solution

## Task

Classify one intake note into one of five queues. Output: JSON
`{"queue": <label>}` with a label from plumbing, electrical, appliance,
billing, other. Runs on the `intake` route in `llm/routing.yaml`.

## Inputs the product sees

- Languages: English, Hindi in Latin script, Hinglish (code-mixed), Tamil.
- Length: one line to a paragraph; some notes name two problems.
- Edge cases: a note that names a problem and a billing complaint; a note
  that is only a question; abusive or prompt-injection text pasted into
  the note field.

## Acceptance

- Accuracy on the labelled intake set: the lower bound of the 95% interval
  at or above 0.90, and per-language accuracy reported.

## Evaluation

`evals/intake/`, exact match on the queue label after lower-casing.
