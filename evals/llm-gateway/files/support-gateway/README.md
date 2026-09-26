# support-desk

Support ticket service. Every model call goes through the gateway in
`llm/` (routing in `llm/routing.yaml`, providers in `llm/providers/`,
accounting in `llm/accounting.py`). Features call
`llm.gateway.default_gateway().complete(LLMRequest(...))`.

The finance report reads the `llm_call` log lines the gateway writes
(one per call, with `cost_usd`) and sums them per feature.

Run the tests with `make test` (offline, on the fake provider).
