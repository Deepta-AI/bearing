# Routing strategies

Three ways to put a feature on a model. `model-routing` measures the first
two and writes one of them; the third is described for the product that
needs it.

## Static

One model per feature, set in `llm/routing.yaml` (`strategy: static`).
The cheapest candidate whose interval's lower bound meets the threshold.
Simple to reason about, one prompt cache, one failure mode.

The route carries one leg,
`leg: {model: <key>, effort, max_tokens, timeout_s}`, the settings the
eval measured. The tier is not read, so a
route moved from a `balanced` tier to Haiku 4.5 does not keep the tier's
`effort`.

Before building a cascade, add the larger model at a lower effort as a
candidate of its own: a `models:` row of its own, which the eval override
and a static leg both read.

```yaml
sonnet-low: { provider: anthropic, id: claude-sonnet-5-5, effort: low, max_tokens: 4096, timeout_s: 60, input_per_m: 2.00, output_per_m: 10.00 }
```

`id` is the model the provider gets; the key names the row, its prices
and the results file. On current models a lower effort often holds
quality at a fraction of the output tokens, and one model keeps one
cache. Haiku 4.5 takes no `effort` (the `claude-api` skill's thinking
table: it errors), so its row sets `effort: null` and the gateway sends
it none, from an override, a static leg or a tier.

## Cascade

The small model answers first. When its answer fails a check the gateway
can run (`escalate_on`: `invalid`, `refusal`, `max_tokens`), the large model
answers once and that answer stands. `invalid` is a JSON schema that does
not parse or a format check (`LLMRequest.check`), the same `valid` that
`llm-eval` records per row; a semantic grader never decides escalation,
because production cannot run it at call time.

Cost per request, with `c_s` and `c_l` the measured cost per request of
the small and large model and `e` the share of requests escalated:

```
cascade = c_s + e * c_l
cheaper than static large when  e < 1 - c_s / c_l
```

Use the measured costs from `route_frontier.py`, not the price ratio: the
two models use different numbers of output tokens for the same answer, and
an invalid small answer is often the longer one. Haiku 4.5 at about half
of Sonnet 5.5's cost per request breaks even near 50 percent escalated;
against Opus 5.5 (about a quarter) near 75 percent.

Score: valid small answers keep the small model's score, escalated ones
take the large model's. A small model that is wrong but valid passes its
error through, which is why the frontier simulates the cascade from both
recorded runs case by case instead of assuming the large model's score.

Latency: an escalated request pays both calls, so the cascade's p95 is the
escalated path's once more than 5 percent of requests escalate.

Cache: prompt caches are scoped to one model, so a cascade forfeits cache
reuse between its two models. On a route with a long cached system prompt
the cache saving can outweigh the cascade's; measure both.

Legs: `cascade.first` and `cascade.then` each name a `models:` key and
carry their own `effort` (null for Haiku 4.5), `max_tokens` and
`timeout_s`. Nothing comes from the route's tier: a Haiku 4.5 leg that
inherited a tier's `effort` would fail every call with a 400. The gateway
sends `effort` only when the leg sets it.

```yaml
cascade:
  first: { model: claude-haiku-4-5, effort: null, max_tokens: 2048, timeout_s: 20 }
  then: { model: claude-sonnet-5-5, effort: medium, max_tokens: 2048, timeout_s: 60 }
```

Gateway: the first call goes to `cascade.first`; the route's fallback,
when that model is unavailable, runs before the cascade judges the
answer. Escalation happens at most once. Each call is recorded under the
model that answered it (`first`, the fallback, or `then`) at that model's
prices, and `llm_escalation_total{feature}` counts the escalation. Alert when the escalation rate
over a day is more than 1.5 times the rate the frontier measured: the
traffic has drifted from the golden set and the saving is no longer the
one that was measured. Re-run `model-routing`.

## Classifier (left to the builder)

A cheap classifier reads each request and picks the tier. It can beat a
cascade when hard requests are recognisable up front, since it never pays
for a wasted small call. It needs per-request difficulty labels (which
requests the small model gets wrong), a classifier eval of its own, and a
gateway hook before the provider call. The first release has none of
these; build it when a product shows the need and the labels exist.

## Budget and alert

`budget_usd_month` on the route: the monthly estimate (cost per 1k x
requests a day x 30 / 1000) with 25 percent headroom, rounded up. The
alert fires at 80 percent of the budget on `llm_cost_usd_total` for the
feature, wired by `bearing:observability`. The estimate is only as good as
the volume: take it from the gateway's `llm_calls` record for the last 30
days, else from the solution doc, and say which.

## Prices

Each candidate is a `models:` key with `provider`, `input_per_m`,
`output_per_m` and a comment naming the price's source and date. Claude
prices come from the `claude-api` skill; another provider's from its
pricing page, pasted by a person with the date. A price from memory is not
a source.
