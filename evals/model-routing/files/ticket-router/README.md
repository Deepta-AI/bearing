# ticket-router

Routes inbound helpdesk tickets to a queue (billing, access, payroll_run,
statutory, security, other). Every model call goes through `llm/`; the
routes and the price table are in `llm/routing.yaml`.

## Triage eval

`evals/triage/results/` holds one recorded run of the triage eval per
candidate model, made in CI on 2026-10-15 with
`make eval EVAL=triage MODEL=<key>` (60 labelled tickets, prompt
triage-v4). Each row carries `valid`: the reply parsed as JSON and named a
label from the closed set, the check the gateway runs at call time.

There is no API key on laptops; the recorded runs are all there is.

## Volume

About 20,000 triage calls a day, all on `claude-sonnet-5-5` today.
