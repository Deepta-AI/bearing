# ticket-triage

Routes inbound support tickets for Brightdesk HR to the right queue. Every
new ticket is classified into one category by a model call
(`triage.classify.classify`), and the helpdesk moves it to that queue.

## Categories

`billing`, `payroll_run`, `statutory` (PF, ESI, TDS, PT filings),
`integrations`, `access` (login, SSO, roles), `security` (suspected account
compromise, data exposure, phishing), `other`.

A `security` ticket must reach the security queue within 15 minutes, so a
security ticket routed anywhere else is the costliest mistake.

## Code

- `triage/prompts.py`: the prompt, `PROMPT_VERSION = "v2"`.
- `triage/classify.py`: builds the request, calls the client, parses the
  JSON reply, returns the category string.
- `triage/llm.py`: `LLMClient` interface and `RecordedLLM`, which replays
  responses captured from the production model on 2026-09-02 for prompt v2
  (`fixtures/recorded/v2.jsonl`). It refuses to replay for a different
  system prompt. Configured model: `claude-sonnet-5`.

## Data

`data/tickets.jsonl` is an export of 60 recent tickets from the helpdesk.
Closed tickets carry `resolved_category`, the queue the support agent
finally resolved the ticket in, and `resolved_by`, the agent. Open tickets
have no `resolved_category` yet.

## Commands

    make test
