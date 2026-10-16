# load-test: workload model worked example and ramp reasoning

Read when you write the workload model (step 2).

- Peak rate from the source, converted to requests a second per route
  (18,000 sign-ups in 15 minutes is 20 a second; at 3 page reads and 1
  submit each, 60 + 20 = 80 requests a second).
- Shape: ramp in seconds, not minutes, because a slow ramp warms caches,
  pools and autoscalers the real event will not have warmed.
