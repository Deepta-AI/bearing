---
name: performance
description: 'Profiles and fixes slowness with the stack''s profiler (pprof, py-spy, clinic, Lighthouse, Instruments), with before and after numbers. Use when told "this is slow", "profile this", "optimise" or "p95 is high".'
argument-hint: "<symptom or endpoint> [--metric p95|cpu|heap|lcp|startup] [--runs 3]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(ls:*), Bash(mkdir -p:*), Bash(make check:*), Bash(make bench:*), Bash(git diff:*), Bash(git status:*), Bash(go test:*), Bash(go tool pprof:*), Bash(uv run py-spy:*), Bash(uv run python -m cProfile:*), Bash(node --cpu-prof:*), Bash(node --heap-prof:*), Bash(npx clinic:*), Bash(npx lighthouse:*), Bash(./gradlew :macrobenchmark:connectedCheck:*), Bash(xcrun xctrace:*), Bash(hyperfine:*), Bash(k6 run:*)
---

# performance

No number, no optimisation. The deliverable is a before and an after
from the same command, and the one change between them.

Not this: `load-test` writes the k6 scripts and thresholds; this
skill may run one to get a p95. `observability` wires the metrics
that tell you it is slow in production.

## Inputs

- Symptom: `$1`, an endpoint, a job, a screen or a sentence; if absent,
  one question: "what is slow, for whom, and how do you know?".
- Metric: `--metric`; if absent, from the symptom: latency for an
  endpoint (`p95`), `cpu` for a job, `heap` for growing memory, `lcp`
  for a page, `startup` for an app. Runs: `--runs`, default 3.
- Stack: `go.mod`, `pyproject.toml`, `package.json`, `build.gradle.kts`,
  `Package.swift`; more than one: the one the symptom lives in.
- Load for an endpoint: an existing k6 script under `loadtest/` or
  `tests/load/`; if absent, `hyperfine` against a local URL with the
  request from the symptom; neither possible: a `go test -bench`, a
  pytest-benchmark, or a timed script written to `.scratch/perf/`.
- Baseline profile: `git status` clean; the profile is taken on HEAD.
- Report path: `docs/performance/<kebab>.md` from
  `templates/perf-report.md`.

## Steps

1. Restate the symptom as a metric and a condition: "p95 of GET
   /orders at 50 rps", "heap after 10k jobs", "LCP on /checkout on
   throttled 4G". Refuse to touch code until this line exists.
2. Measure before: run the load or benchmark from Inputs `--runs`
   times; print "before: N runs, min X, median Y". N=0 or no number
   parsed: stop with "no measurement; nothing to optimise".
3. Profile under the same condition, per stack:
   - Go: `go test -bench . -cpuprofile cpu.out -memprofile mem.out` or
     the `/debug/pprof/{profile,heap,block}` endpoint; `go tool pprof
     -top -nodecount=15 <bin> cpu.out`.
   - Python: `uv run py-spy record -o .scratch/perf/flame.svg -- python
     <entry>`; `uv run python -m cProfile -s cumtime <entry>` for
     call counts.
   - Node: `node --cpu-prof --cpu-prof-dir=.scratch/perf <entry>`,
     `node --heap-prof` for memory, `npx clinic flame -- node <entry>`.
   - Browser: `npx lighthouse <url> --output=json
     --output-path=.scratch/perf/lh.json`; the Performance panel trace
     is recorded by the engineer and its JSON dropped in `.scratch/perf/`.
   - Android: `./gradlew :macrobenchmark:connectedCheck` for startup
     and frame timing; the Studio profiler trace is exported by hand.
   - iOS: `xcrun xctrace record --template 'Time Profiler' --launch
     <app> --output .scratch/perf/trace.trace`.
   Read the flame graph: the widest frames by self time, then the
   path from the root that carries the most total time. Print "top
   frames: N" and list five with their share.
4. One hypothesis, named as a frame and a cause: N+1 query, allocation
   in a hot loop, missing index, synchronous IO on the request path,
   unbounded cache or map, lock contention, re-render storm, unindexed
   JSON scan, retained closure. One at a time; the second waits.
5. The smallest change that tests the hypothesis. `make check`; print
   the test count. A behaviour change is a feature: stop with "that is
   a feature; use start-task".
6. Measure after with the exact command from step 2, same runs. Print
   "after: N runs, min X, median Y, delta Z%". Median inside the
   before run's spread is noise: say so, revert, next hypothesis.
7. Write the report from `templates/perf-report.md` (create the
   directory) with both commands, both numbers, the profile paths, the
   diff summary and what was not tried. Print the contract.

## Output contract

```
## Perf: <symptom> as <metric> under <condition>
Before: N runs, min X, median Y   (command: <...>)
Profile: <tool> top frames: N; widest <frame> S%
Hypothesis: <frame>: <cause>
Change: <one line>, files N, tests N passed
After: N runs, min X, median Y, delta Z%   (same command)
Report: docs/performance/<kebab>.md
Not tried: <next hypotheses> | none
```

## Gotchas

- A profile of a warm cache, an empty table or a debug build measures
  the wrong program. Say which build, which data size, which warmup.
- The widest frame is often the runtime (GC, event loop, JSON). The fix
  is in the frame that calls it too often, one level up the path.
- p95 from three runs of ten requests is not a p95. The report says
  the sample size next to every number.
- Memory that grows and plateaus is a cache; memory that grows and does
  not is a leak. Take two heap profiles minutes apart and diff them.
- A 40% win on a path that runs once a day is not the win the user
  asked for. Weight by how often the condition happens.
- Never optimise from a flame graph the engineer described in chat.
  The file is in `.scratch/perf/` or the profile step did not happen.
