---
name: load-test
description: 'Writes k6 load tests from the SLOs with failing thresholds (smoke, load, stress, soak) and a manual CI job; refuses production. Use when asked to "load test", "performance test the API", "soak test" or "hold p95".'
argument-hint: "<local|qa|base URL> [smoke|load|stress|soak, default smoke]"
allowed-tools: Read, Write, Edit, Grep, Glob, Skill, Bash(ls:*), Bash(make:*), Bash(k6 run:*), Bash(k6 inspect:*), Bash(k6 version:*), Bash(uv run locust:*), Bash(curl -fsS:*)
---

# load-test

An SLO nobody has tested is a guess. This skill turns the HLD's numbers
into thresholds that fail a run, keeps every script under `tests/load/`,
and never points at production.

## Inputs

- Target: `$1`; if absent, `local` when the Makefile or `.env.example`
  names a port, else asks one question: "which base URL: local, qa or a
  URL?". No answer: stop with "provide a base URL".
- Production host: looks in `.gitlab-ci.yml` (`deploy-production`
  environment); if absent, the check falls back to the `prod` substring
  and, for a raw URL, one question: "is <host> production?". A yes stops.
- SLOs: looks in `docs/design/*-hld.md` sections 7 and 9; if absent, the
  stated defaults (p95 under 500 ms, error rate under 1%, throughput
  50 requests per second) and the results file says "defaults, no HLD".
  The fuller numbers come from `high-level-design`.
- Endpoints: looks in `docs/testing/test-scenarios.md` (Performance rows),
  else the HLD's top five by traffic, else the routes in the code
  (`api/openapi.yaml`, router files, handler registrations); always
  `/healthz`. No routes anywhere: one question for a path. Nothing: stop
  with "provide at least one endpoint path".
- Test data builders: the repository's builders; if absent, literal JSON
  in `tests/load/data/`.
- Template: `templates/k6-script.js` in this skill's folder.
- Script engine: Grafana's `k6` skill when installed (its protocol
  examples, docs lookup, validate loop and best-practices review); if
  absent, the template alone.
- CI: `.gitlab-ci.yml`; if absent, the Makefile target is wired and the
  job snippet is printed for when a pipeline exists.

## Steps

1. Resolve the target as in Inputs. `local` is `http://localhost:<port>`;
   `qa` is the `deploy-qa` environment URL in `.gitlab-ci.yml` (absent:
   ask for it); a raw URL is used as given. Before writing anything,
   compare the target host with the production host. A match, or a host
   containing `prod`, stops the run with "refused: production URL". Stage
   from `$2`, default `smoke`.
2. SLOs as in Inputs: p95 latency, error rate and throughput per endpoint
   or flow. Throughput is 1.5 times the HLD's expected peak when the HLD
   gives one, else the default 50 rps; the results file names the source.
3. Tool: k6 for every stack. Locust only when the repository is Python and
   neither Node nor a k6 binary is available in CI; say which and why in
   the results file.
4. Endpoints as in Inputs; list them with their source before writing.
5. Write `tests/load/<flow>.js` from `templates/k6-script.js`. When the
   `k6` skill is installed, load it (Skill tool) for this step and the
   validation: it picks the example for the protocol (HTTP, gRPC,
   WebSocket, browser), looks up any API the template lacks and reviews
   the script against its best practices. This skill's contract wins
   over its defaults: the file goes to `tests/load/`, not `k6/scripts/`;
   the thresholds, stages, `x-load-test` header, `setup()`, `teardown()` and
   `handleSummary()` below stay even though its rule says not to add
   unrequested options; validate an arrival-rate script with
   `k6 inspect tests/load/<flow>.js`, never a full run at this step; and
   skip its cloud run suggestions. Without it, adapt the template by
   hand. Either way the script has: thresholds
   with `abortOnFail`, stages selected by `STAGE` (`smoke` 1 VU for 1 min,
   `load` ramp to the peak for 5 min, `stress` to twice the peak, `soak` at
   the peak for 30 min), test data in `tests/load/data/*.json`, a `setup()`
   that logs in once and a `teardown()` that deletes what the run created.
   Every request carries an `x-load-test: <run id>` header so logs can be
   filtered.
6. Wire: `make load-test` (`STAGE`, `BASE_URL`), failing on zero scripts and
   printing the script count, with the same production-host refusal. CI job
   `load-test` in stage `verify`, `when: manual`, `needs: [deploy-qa]`,
   `BASE_URL` fixed to the qa URL, `allow_failure: false`, the summary JSON
   kept as an artifact.
7. Run the requested stage when a k6 binary is present and the target
   answers `/healthz`. Append the run to the results table in
   `docs/testing/load-tests.md` (create it): date, commit, stage, VUs, p50,
   p95, p99, error rate, throughput, threshold verdict. Without a binary,
   write the files and say the run was skipped.
8. Print the counts.

## Output contract

```
## Load test: <target> (<stage>)
Target: <url>   Production check: passed
SLO source: HLD section 7 | defaults (p95 500 ms, errors 1%, 50 rps)
Endpoints: N (from scenarios | HLD | code)   Scripts written: S   Thresholds: T
Run: p95 <ms> (limit <ms>)  errors <%> (limit <%>)  rps <n> (floor <n>)  verdict pass | fail | skipped (no k6)
Files: tests/load/..., docs/testing/load-tests.md, Makefile, .gitlab-ci.yml | (no CI file: snippet printed)
```

## Gotchas

- A threshold set above what the system already does checks nothing.
  Thresholds come from the SLO. A run that passes with 10x headroom means
  the SLO is wrong, not that the test is good. Defaults are a floor to
  start from, and the results file must say they were used.
- Soak runs create data. Without `teardown()` the qa database grows until a
  later run fails for the wrong reason.
- `http_req_duration` includes connection setup on each VU's first request.
  Threshold `http_req_waiting` for server latency.
- Never run `stress` or `soak` from a laptop against a shared qa. The client
  saturates first and the numbers describe the Wi-Fi.
- The production check compares hosts, not strings. `https://api.example.com`
  and `https://api.example.com:443/` are the same host.
- The `k6` skill suggests `k6 cloud run`. The repository settings deny it,
  and a cloud run sends load from Grafana's zones to whatever the script
  names, past the production check here. Local and CI runs only.
- Load tests are not in `make check`. They run on demand against qa, and
  a run is only evidence for the commit it names.
