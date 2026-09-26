# Evals

## ticket_summary

Golden set: 100 closed tickets from July 2026 (`evals/ticket_summary/cases.jsonl`),
PII removed. Graded by a rubric (covers the customer's problem, the
resolution, any follow-up owed; no invented facts) with a judge model;
score is the share of summaries that pass all four rubric lines.

Acceptance threshold: 0.85.

| Date | Model | Effort | Score | Tokens in / out (mean) |
| --- | --- | --- | --- | --- |
| 2026-08-04 | claude-opus-5 | low | 0.91 | 1,480 / 140 |
| 2026-08-04 | claude-sonnet-5 | medium | 0.87 | 1,480 / 150 |
| 2026-08-04 | claude-haiku-4-5 | n/a | 0.78 | 1,480 / 135 |

Volume: about 180,000 closed tickets a day across all customers.

Budget: finance has capped ticket summaries at USD 5,000 a month from
the next quarter.
