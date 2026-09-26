# ticket-summaries

Writes a three-line summary of every closed support ticket for the
account managers' weekly review. The call goes through the gateway
route `ticket_summary` in `llm/routing.yaml` (Opus 5 today).

- `data/teacher/summaries.jsonl`: Opus 5 summaries collected from the
  gateway log in August and September for distillation. Each line is a
  chat record with the ticket id.
- `evals/ticket_summary/cases.jsonl`: the golden set (100 tickets) and
  `docs/genai/evals.md`: the scores so far.

Run the tests with `make test`.
