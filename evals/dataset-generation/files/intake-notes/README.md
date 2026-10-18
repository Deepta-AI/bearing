# fixit-intake

Classifies a customer's intake note for a home repair booking into a queue
(plumbing, electrical, appliance, billing, other). Every model call goes
through `llm/`; routes and prices are in `llm/routing.yaml`.

## Intake eval

`evals/intake/cases.jsonl` is the golden set: 40 real notes from the
booking app (PII removed), each labelled by the support lead. It is the
only labelled data we have. Grading is exact match on the queue label.

## The gap

Real notes are short English messages from the city. The app now opens in
two new cities, where notes arrive in Hindi, Hinglish and Tamil, and the
team has seen long multi-problem notes ("fan and tap and the bill") that
the set does not cover. See `docs/genai/intake-solution.md`.
