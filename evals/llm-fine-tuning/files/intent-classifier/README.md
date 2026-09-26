# cx-intents

Labels every inbound customer message with an intent so it reaches the
right team. The model call goes through `llm/routing.yaml` (route
`ticket_intent`, Haiku) with the system prompt in
`app/prompts/intent_system.txt`.

- `data/intents_labelled.jsonl`: messages labelled by the CX leads.
- `logs/intent_predictions_2026-09.jsonl`: what production predicted
  for those same messages (exported from the gateway's call log).

Run the tests with `make test`.
