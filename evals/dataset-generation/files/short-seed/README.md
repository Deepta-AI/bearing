# fixit-intake

Classifies a customer's intake note for a home repair booking into a queue
(plumbing, electrical, appliance, billing, other).

## Intake eval

`evals/intake/cases.jsonl` holds every labelled note we have: six real
notes from the booking app, labelled by the support lead. The classifier
calls the model through `llm/` on `claude-sonnet-5-5`.
