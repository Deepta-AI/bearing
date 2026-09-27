---
name: load-test
description: 'Writes k6 load tests from the SLOs with failing thresholds (smoke, load, stress, soak) and a manual CI job; refuses production. Use when asked whether it "holds at peak", to "load test" or "soak test".'
argument-hint: "<local|qa|base URL> [smoke|load|stress|soak, default smoke]"
allowed-tools: Read, Write, Edit, Grep, Glob, Skill, Bash(ls:*), Bash(make:*), Bash(k6 run:*), Bash(k6 inspect:*), Bash(k6 version:*), Bash(uv run locust:*), Bash(curl -fsS:*)
---

# load-test

A load test answers one question with a number: does this service, in
this environment, meet this SLO at this rate. Most load tests that pass
are wrong in a quiet way: they measure the rate limiter, a warm cache,
the load generator or a smaller environment, and nobody notices because
the result is green. This skill is mostly about the traps that make a
result mean something else, then about writing the script.

## Inputs

- Target: `$1`; if absent, `local` when the Makefile or `.env.example`
  names a port, else one question: "which base URL: local, qa or a URL?".
  No answer: stop with "provide a base URL".
- Production hosts: every host a production environment answers on, from
  all of: CI environment URLs (the production deploy job and any job whose
  environment is production), deploy values and ingress hosts, `.env*`
  files, the README and runbooks. A production host rarely contains
  "prod"; compare against the list, not a substring. None found and the
  target is not local: one question, "is <host> production?"; a yes stops.
- Rates and SLOs: the newest accepted design doc (HLD sections 7 and 9 on
  this standard), ADRs, incident notes. Older sources (README targets,
  scenario tables, bench scripts) lose to a newer accepted document that
  supersedes them; say which was used and which was ignored. No SLO
  anywhere: p95 500 ms and errors 1%, and the results say "defaults, no
  HLD".
- Routes, auth and valid bodies: from the code (router, handlers,
  validation, auth middleware), never from docs alone; docs name routes
  that no longer exist.
- Limits and environment shape: rate limits (per key, per IP, per pod),
  replicas, CPU and memory limits per environment, scheduled scale-downs
  or maintenance windows, CI job timeouts.
- Template: `templates/k6-script.js` in this skill's folder. Grafana's
  `k6` skill, when installed, helps with protocol examples and API
  lookup; the rules here win over its defaults (file location,
  thresholds, no cloud runs).

## Steps

1. Resolve the target: `local` is `http://localhost:<port>`, `qa` the qa
   environment URL from CI, a raw URL as given. Compare the target host
   (lower case, port and path stripped) with every production host from
   Inputs. A match stops with "refused: production URL". Also list any
   script or variable already in the repository that defaults to a
   production host (bench scripts, Makefile defaults) and flag it.
2. Workload model, written down with its arithmetic before any script:
   - Peak rate from the source, converted to requests a second per route
     (18,000 sign-ups in 15 minutes is 20 a second; at 3 page reads and 1
     submit each, 60 + 20 = 80 requests a second). The pass criterion is
     at this rate. Headroom (1.5x, 2x) is a separate stress stage, never
     the load stage's target.
   - Shape: how fast the real peak arrives and how long it lasts. An event
     that opens at a fixed time is a step: ramp in seconds, not minutes,
     because a slow ramp warms caches, pools and autoscalers the real
     event will not have warmed. Hold for the real peak's duration, plus a
     short cool-down.
   - Mix: the ratio between routes from the flow, and the data mix. Values
     that key a cache (query strings, IDs, pages) need the cardinality and
     repeat ratio of real traffic; a short fixed list turns a search test
     into a cache test. Read the cache code to see what the key is.
   - Soak rate: the normal busy-hour rate from the source, not a number
     chosen only to stay under a limit.
3. Environment fit. Say, with numbers, what a run on this target can and
   cannot show:
   - Rate limits: the target rate divided by 80% of the per-key limit
     gives the keys needed (a bucket driven at exactly its rate still
     rejects on jitter). Not enough keys: the run is invalid until more
     exist; say how many. 429s are then a test fault, not a service result.
   - Size: when the target is smaller than production (fewer replicas,
     less CPU or memory), the full peak on it proves nothing either way.
     Offer the per-pod share (peak / production replicas, scaled for CPU
     per pod) as what this environment can test, or scaling it to
     production shape for a window. Never extrapolate linearly past one
     pod's share; shared state does not scale that way.
   - Schedules: a scale-to-zero or maintenance window inside the run kills
     it. State the window the run must fit, or what must be paused and who
     is told. A long run from CI needs a job timeout longer than the run.
   - Side effects: what the run writes (orders, users, files), where it
     stays, and whether that growth distorts this or later runs. Delete
     through an API the service really has; if none exists, tag the data
     (an email pattern, the `x-load-test` run id) and write down the
     cleanup. Never call an endpoint the code does not serve.
4. Write `tests/load/<flow>.js` from the template:
   - Open model: an arrival-rate executor in the unit of the flow
     (checkouts a second). Size `preAllocatedVUs` from Little's law (rate
     x p99 seconds x 2) and fail on `dropped_iterations` above 1% of
     planned: when the generator falls behind, the service did not see the
     rate you claim.
   - Requests exactly as the code serves them: path, query parameter
     names, auth header, bodies that pass validation (read the validator
     and the reference data such as ID ranges). A body that 400s measures
     the error path.
   - Thresholds from the SLO, per route (tag each request with a `name`
     and threshold the `{name:...}` submetric), on `http_req_waiting`
     where connection setup would pollute the figure. The error threshold
     counts what the SLO counts. k6's `http_req_failed` counts every
     status from 400 up, so 429s and 400s land in it; use a custom rate of
     5xx plus timeouts (status 0) and give 429 and other 4xx their own
     counters and limits.
   - `abortOnFail` only where the rest of the run would be worthless: auth
     failures, a flood of 429s, nearly every request failing. Never on
     latency in a soak (a pod slowing as memory grows is the evidence),
     and in a load stage only with `delayAbortEval` past the ramp.
   - No remote imports (`https://jslib.k6.io/...`): a CI runner may have
     no internet, and the script changes under you. Summary through
     `--summary-export`.
   - Every request carries `x-load-test: <run id>`.
5. A soak for a leak adds, on top of step 4:
   - Hypotheses from the code: every structure that grows with input and
     never shrinks (maps used as caches, in-memory stores, per-client
     buckets, pools). Name the file and field.
   - Load that grows the suspect the way real traffic does. Cardinality
     alone is not enough: an entry's size depends on what is stored. A
     result cache grows many times faster on queries that return data
     than on random strings that match nothing. Build keys from real
     values (real words, prefixes, case and spacing variants, pages) and,
     when a local instance can be started, measure heap per entry.
   - Estimate before running: expected growth over the run (from that
     measurement, or from the growth observed in the environment, in Mi an
     hour) against the memory limit. A soak whose expected growth is
     inside normal heap noise proves nothing; raise the distinct-key rate
     or lengthen the run.
   - Separate the hypotheses: phases or runs that exercise one suspect at
     a time, with a control (repeated keys that should stay flat). One
     mixed load that rises proves only that something grows. Writes that
     grow memory on their own stay out of the other phases.
   - Sample memory on a clock, independent of the load: the runtime's own
     figures (Go expvar `/debug/vars` memstats, `/metrics`
     `process_resident_memory_bytes`, JVM MXBeans) and, where reachable,
     the container's working set, which is what the OOM killer reads (a
     Go heap figure is not the process size). Keep uptime or a monotonic
     counter with each sample so an OOM restart mid-run reads as a
     restart, not as memory levelling off.
   - Reading: discard warm-up; a leak is a slope that stays positive after
     the working set should have levelled off, per phase, in Mi an hour,
     projected to the container limit as hours to OOM.
6. Wire: `make load-test` (`STAGE`, `BASE_URL`, keys through the
   environment), refusing production hosts, failing on zero scripts and
   printing the script count. `make check` never runs it. A CI job only
   when a pipeline exists: `when: manual`, qa only, after the qa deploy,
   `allow_failure: true` so an unplayed job does not leave every pipeline
   blocked (a played job still shows red), a `timeout` above the longest
   stage, results kept as artifacts.
7. Check what can be checked here: the script parses (`k6 inspect` when
   k6 exists), the make target refuses a production host and fails on
   zero scripts. When the service can be started locally (a process you
   start, on a free port), smoke the request shapes against it with
   `curl -fsS`; label any figure from it "local, not <target>".
8. Run the requested stage only when k6 is present and the target
   answers its health check. Append the run to `docs/testing/load-tests.md`:
   date, commit, stage, rate planned and achieved, p95 per route, error
   rate, verdict. Without a run the row says "not run", and no figure
   appears anywhere as measured.
9. Change nothing in the service, deploy config or schedules. More keys,
   raised limits, replicas, a paused schedule: propose them in the final
   message with who has to act.

## Output contract

The final message carries, in any layout:

```
Target: <url>   Production hosts checked: <n> (<hosts>)   refused | passed
Workload: <source> -> <arithmetic> -> <rate per route>, ramp <s>, hold <min>
Thresholds: <route> p95 <ms>; errors <%> (<what counts>); dropped <%>; 429 <limit>
Environment: keys needed <n> (have <n>); <target> vs production shape; what a run here shows
Before running: <keys, window or paused schedule, data cleanup, who acts>
Run: <command with BASE_URL and keys>   Results: <where>
Status: not run (<why>) | <figures, labelled with the environment>
Noticed: <production defaults, stale docs, anything else>
```

No capacity verdict ("holds", "will fail") without a measured run on an
environment that can answer the question.

## Gotchas

- A threshold above what the system already does checks nothing. A pass
  with 10x headroom means the SLO or the test is wrong.
- Rate limiters are often per pod, not global: one key gets its limit on
  a one-pod qa and the limit times the replicas in production. Read the
  limiter before counting keys.
- The load generator is part of the system under test. A laptop on Wi-Fi
  saturates first; watch `dropped_iterations` and the generator's CPU.
- A fixed number of looping VUs slows down when the service slows down,
  so it reports healthy latency at a lower rate than asked (coordinated
  omission). An arrival-rate executor avoids it.
- Percentiles do not average or add: threshold each route, never a mean
  of p95s.
- A soak that aborts on latency stops exactly when the leak starts to
  show.
- `k6 cloud run` sends load from outside, past every host check here.
  Local and CI runs only.
- A run is evidence for the commit and environment it names, nothing
  else.
