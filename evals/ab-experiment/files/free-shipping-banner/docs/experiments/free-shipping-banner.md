# Experiment: free shipping banner on the product page

Status: running (started 2026-09-01, planned end 2026-09-22)
Flag: `free-shipping-banner` in config/flags.json, 50/50 by device id

## Hypothesis

If we show a "free shipping over 499" banner at the top of the product page
for every visitor on web and app, the share of exposed devices that place an
order rises by at least 0.5 points (from 5.0%) because shipping cost is the
top reason given in the cart exit survey.

## Metrics

| Role | Event | Per exposed device | Baseline | Harm direction |
| --- | --- | --- | --- | --- |
| primary | `order_placed` | share of devices with an order within 7 days of exposure | 0.050 | n/a |
| guardrail | `order_refunded` | share of devices with a refund | 0.004 | up |
| guardrail | product page p95 load time | milliseconds | 1,850 ms | up |

## Sample size

Two-proportion test, alpha 0.05 two-sided, power 0.8, baseline 0.05,
minimum effect 0.005 absolute (10% relative):
29,792 devices per variant, 59,584 in total. About 21,000 eligible devices a
week, so 3 weeks.

## Rules

- Read once, at the planned end, when both variants have at least 29,792
  exposed devices.
- Stop early only if a guardrail is clearly worse or the split between
  variants is off (sample ratio check, p under 0.001).
- Ship if `order_placed` is up by at least 0.5 points with p under 0.05 and
  no guardrail is worse. Kill if it is flat or down. If short of the sample
  at the planned end, extend once by one week.
