# Pattern: rate_limit

A limit protects the other callers, not the server. It is enforced at
the edge with one algorithm, one key scheme and standard headers, and it
is tested with a clock, not with sleeps.

Markers: `RateLimit|X-RateLimit|Retry-After|token bucket|sliding window|golang.org/x/time/rate|slowapi|limiter|429`
Decision keys (ADR grep): `rate limit`, `throttl`, `quota`

## Decision questions

1. What is being protected, with numbers: the login endpoint (brute
   force), an expensive query, a third-party quota, or fairness between
   tenants? Each gets its own limit; one global number protects nothing.
2. Algorithm: token bucket (allows bursts up to the bucket, smooth
   average; recommend for APIs), sliding window log or counter (exact
   per window, no burst; recommend for login and OTP), fixed window
   (simplest, double burst at the boundary; avoid).
3. Key: per API key, per user, per tenant, per IP (only for anonymous
   endpoints; NAT hides thousands behind one IP)? Recommend a layered
   key: per user inside per tenant, with the tenant limit larger.
4. Where enforced: the gateway or ingress (cheap, coarse), the service
   middleware (knows the user and tenant; recommend), or both.
5. Storage: in process (per node, allows N times the limit across N
   nodes), or Redis (shared, one round trip). Recommend Redis for
   anything user-facing; in process only for a single-node worker.
6. Behaviour at the limit: reject with 429 (recommend), queue with a
   bounded wait, or degrade (drop the expensive part of the response).

## Data model

```
Redis token bucket, one key per limit and subject:
  rl:<limit>:<subject>  -> hash {tokens, updated_at_ms}, TTL = 2 * refill period
Lua script: refill by elapsed * rate, cap at burst, take 1 if available, return remaining and reset
Sliding window counter: rl:<limit>:<subject>:<window start> counters, weighted sum of current and previous
```

Configuration lives in code as a table: `name, algorithm, rate, burst,
key kind, scope`; overrides per tenant in a `tenant_limits` table read
through the tenant context, never by editing code.

## Headers

```
RateLimit-Limit: 100        RateLimit-Remaining: 42        RateLimit-Reset: 17
429 with Retry-After: 17 and a JSON body {error: "rate_limited", limit, reset_seconds}
```

The same headers on 2xx so clients can back off before hitting 429.

## Failure modes

| Fault | Handling |
| --- | --- |
| Redis down | fail open with a local in-process bucket at a lower rate; alert; never fail closed on a login path |
| clock skew between nodes | the bucket uses Redis server time (`TIME` in the script), never node time |
| NAT and shared IPs | IP limits are generous and only for anonymous endpoints; authenticated limits use the user |
| retry storms after 429 | `Retry-After` honoured by the SDK; jitter documented; a client that ignores it is cut at the tenant limit |
| limit per node instead of global | test with two nodes sharing Redis |
| tenant starves its own users | per-user limit inside the tenant limit; the tenant limit is the sum plus headroom |
| a limit on the health endpoint | never; allow-list `/healthz`, `/readyz` |

## Tests to write

- burst of `burst` requests passes, the next is 429 with `Retry-After` (fake clock)
- after `reset` seconds one more request passes
- two subjects do not share a bucket
- two nodes with one Redis enforce one global limit
- the 2xx response carries the three `RateLimit-*` headers with correct values
- Redis unavailable: requests pass at the fallback rate and the metric increments
- tenant override in `tenant_limits` takes effect without a restart

## Per-stack pointers

- Go: `golang.org/x/time/rate` for in process; a Lua script over `go-redis` for shared; middleware on the mux before auth for IP limits and after auth for user limits.
- Python: `slowapi` or a Starlette middleware with `redis.asyncio` and the same Lua script.
- Gateway: nginx `limit_req` zone for the coarse IP layer; Kong or Envoy `ratelimit` filter when a gateway exists.
- Clients (React, RN, mobile): read `Retry-After`, back off with jitter, surface "try again in N seconds" from the header, never a hard-coded number.
