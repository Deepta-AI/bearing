---
name: performance
description: 'Finds and fixes slowness by profiling first (pprof, py-spy, clinic, Lighthouse, Instruments), with before and after numbers. Use when something is slow: "this is slow", "profile this", "p95 is high".'
argument-hint: "<symptom or endpoint> [--metric p95|cpu|heap|peak|lcp|startup] [--runs 3]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(ls:*), Bash(mkdir -p:*), Bash(make check:*), Bash(make bench:*), Bash(git diff:*), Bash(git status:*), Bash(git log:*), Bash(git worktree add:*), Bash(git worktree remove:*), Bash(go test:*), Bash(go build:*), Bash(go run:*), Bash(go tool pprof:*), Bash(python3:*), Bash(python:*), Bash(uv run python:*), Bash(uv run py-spy:*), Bash(uv run python -m cProfile:*), Bash(node --cpu-prof:*), Bash(node --heap-prof:*), Bash(node:*), Bash(npx clinic@13.0.0:*), Bash(npx lighthouse@13.5.0:*), Bash(./gradlew :macrobenchmark:connectedCheck:*), Bash(xcrun xctrace:*), Bash(hyperfine:*), Bash(k6 run:*), Bash(curl:*), Bash(kill:*)
---

# performance

No number, no optimisation. The deliverable is a before and an after
from the same command at the production size, compared with the
objective the repository states, and the changes between them. The
work is done when the objective is met or the user is told plainly
what still stands in the way; not when the first hypothesis is fixed.

Not this: `load-test` writes the k6 scripts and thresholds; this
skill may run one to get a p95. `observability` wires the metrics
that tell you it is slow in production.

## Inputs

- Symptom: `$1`, an endpoint, a job, a screen or a sentence; if absent,
  one question: "what is slow, for whom, and how do you know?".
- Metric: `--metric`; if absent, from the symptom: `p95` for an
  endpoint, `cpu` for a job, `heap` for memory that grows over time,
  `peak` for a single run that is too big (an OOMKill is always both:
  see step 3), `lcp` for a page, `startup` for an app. Runs: `--runs`,
  default 3.
- Stack: `go.mod`, `pyproject.toml`, `package.json`, `build.gradle.kts`,
  `Package.swift`; more than one: the one the symptom lives in.
- Load for an endpoint: an existing k6 script under `loadtest/` or
  `tests/load/`; if absent, `hyperfine` or a timed client against a
  local server you start yourself; neither possible: a `go test -bench`,
  a pytest-benchmark, or a timed script under `.scratch/perf/` (or the
  scratch folder you were given).
- Baseline: `git status` clean, profile on HEAD. Keep a runnable copy
  of HEAD (`git worktree add .scratch/perf/before HEAD`, or a built
  binary) so the before can be rerun next to the after.
- Report path: `docs/performance/<kebab>.md` from
  `templates/perf-report.md`, when the repository keeps docs.

## Steps

1. Find the finish line in the repository before touching anything:
   the objective (SLO, latency budget, memory limit in the deploy
   manifest, frame budget) and the production size (sizing notes, SLO
   docs, snapshot sizes, row counts, events per hour, the largest
   tenant). Print "objective: <number> from <file>; production size:
   <numbers> from <file>". Seeds, benchmarks and dev defaults in the
   repo are usually far smaller than production and hide exactly the
   quadratic you are looking for; never measure at their size alone.
   Also read the notes and runbooks that already blame something:
   they are a hypothesis to test, not a finding.
2. Restate the symptom as a metric and a condition at that size: "p95
   of GET /orders, largest tenant (60k orders), sequential client",
   "retained heap after each of 12 exports and peak heap of one
   export at the peak-hour volume". Refuse to touch code until this
   line exists.
3. Measure before: run it `--runs` times; print "before: N runs, min X,
   median Y, at <size>". N=0 or no number parsed: stop with "no
   measurement; nothing to optimise". Memory has two numbers and an
   OOMKill needs both: growth per iteration in one long-lived process
   (a leak kills after hours) and the peak of one iteration at the
   largest volume (a spike kills at once). Compare each with the limit,
   remembering the runtime's own baseline (a Python process is 20 to
   40 MiB before your data; RSS runs above tracemalloc's count).
4. Profile under the same condition, per stack:
   - Go: `go test -bench . -cpuprofile cpu.out -memprofile mem.out` or
     the `/debug/pprof/{profile,heap,block,mutex}` endpoint; `go tool
     pprof -top -nodecount=15 <bin> cpu.out`. Add `-benchmem`;
     allocations per op are often the real cost (GC share in the
     profile is allocation, attributed elsewhere).
   - Python CPU: `uv run py-spy record -o .scratch/perf/flame.svg --
     python <entry>`, or `python3 -m cProfile -s cumtime <entry>` for
     call counts when py-spy is not installed.
   - Python memory: `tracemalloc` from the standard library. Start it,
     run one iteration, `gc.collect()`, take a snapshot; repeat; print
     `snap2.compare_to(snap1, "lineno")[:10]` for what is retained and
     grows, and `tracemalloc.get_traced_memory()` (reset with
     `tracemalloc.reset_peak()`) for each iteration's peak.
     `resource.getrusage(resource.RUSAGE_SELF).ru_maxrss` gives the
     process peak in KiB on Linux.
   - Node: `node --cpu-prof --cpu-prof-dir=.scratch/perf <entry>`,
     `node --heap-prof` for memory, `npx clinic@13.0.0 flame -- node <entry>`.
   - Browser: `npx lighthouse@13.5.0 <url> --output=json
     --output-path=.scratch/perf/lh.json`; the Performance panel trace
     is recorded by the engineer and its JSON dropped in `.scratch/perf/`.
   - Android: `./gradlew :macrobenchmark:connectedCheck` for startup
     and frame timing; the Studio profiler trace is exported by hand.
   - iOS: `xcrun xctrace record --template 'Time Profiler' --launch
     <app> --output .scratch/perf/trace.trace`.
   Read it: the widest frames by self time, then the path from the root
   carrying the most total time. List the top five with their share,
   and give the share of anything a note or runbook blamed.
5. One hypothesis, named as a frame and a cause: N+1 query, allocation
   or compile in a hot loop, linear lookup inside a loop, missing
   index, synchronous IO on the request path, unbounded module-level
   cache, set or map, whole result set loaded when it could stream,
   lock held across slow work, re-render storm, retained closure.
6. The smallest change that tests it. Before trusting it, prove the
   output did not change: run old and new on the production-sized input
   and compare the output byte for byte, and when a check is rewritten
   (a regexp by hand, a parse by a slice), test the near misses too.
   Regexp classes differ by language: Go's `\d` is ASCII only, Python's
   `\d` and `str.isdigit()` accept other scripts' digits; `len` counts
   bytes in Go and code points in Python. Then `make check`; print the
   test count, and add tests for every documented contract the change
   touches that no test covered.
7. Measure after with the exact command from step 3, same size, same
   runs; iteration flags may differ only if both sample sizes are
   printed. Rerun before and after alternately (A, B, A, B) when the
   machine is shared or the delta is under 2x. Print "after: N runs,
   min X, median Y, delta Z%". Median inside the before run's spread is
   noise: say so, revert, next hypothesis.
8. Compare with the objective from step 1. Not met, or a memory peak
   above about 70% of the limit: profile again on the new code (the
   top frame has changed) and go back to step 5. Each change is
   measured on its own, so the report can say what each one bought.
   Stop when the objective is met with margin, or when the next change
   would alter behaviour or need a decision; then say which.
9. Write the report from `templates/perf-report.md` (create the
   directory) with the commands, the numbers, the profile paths, the
   diff summary and what was not tried. Print the contract. Leave the
   change uncommitted in the working tree for the engineer; never stage
   build output (`__pycache__`, binaries, profiles).

## Behaviour changes

- A change that alters what users get (different rows, a new field, a
  new flag, a cache that can serve data older than the last write) is
  a feature: stop with "that is a feature; use start-task".
- A fix that also repairs documented behaviour that was broken (the
  runbook's procedure silently did nothing, a documented contract was
  violated) is not a feature: the documentation already promised it.
  Keep it, add the test that failed before, and tell the user: what
  was broken, since when (every run of a long-lived process, since the
  last restart), and what they should check that was produced while
  it was broken.
- Correct the note or runbook whose diagnosis the profile disproved, or
  tell the user it is wrong and why, with the measured number.

## Output contract

```
## Perf: <symptom> as <metric> under <condition>
Objective: <number> (<file>); production size: <numbers> (<file>)
Before: N runs, min X, median Y   (command: <...>)
Profile: <tool>; widest <frame> S%; <blamed suspect> S%
Changes: <frame: cause -> change, delta each>, files N, tests N passed
After: N runs, min X, median Y, delta Z%   (same command)
Against objective: met | not met, because <...>
Measured on: <this machine, local server, seed at size, benchmark>; production not observed
Report: docs/performance/<kebab>.md | none
Not tried: <next hypotheses> | none
```

## Gotchas

- A profile of a warm cache, an empty table or a debug build measures
  the wrong program. Say which build, which data size, which warmup.
- The widest frame is often the runtime (GC, event loop, JSON). The fix
  is in the frame that calls it too often, one level up the path.
- p95 from three runs of ten requests is not a p95. Say the sample size
  next to every number.
- Memory that grows and plateaus is a cache; memory that grows and does
  not is a leak. An `lru_cache` keyed by a bounded set (accounts,
  regions) plateaus; check the key count before blaming it. A
  module-level set or dict that only ever gains is the usual leak.
- Fixing the leak can leave the peak: `fetchall()` plus a built list of
  a peak-volume batch can alone exceed the limit. Iterate the cursor
  and write as you go; if ordered input puts duplicates next to each
  other, dedupe against the previous key instead of a set.
- A hot path under a lock is paid by every writer waiting on it. When
  the slow code runs under a mutex another endpoint needs, give the
  lock hold time before and after next to that endpoint's objective.
- Never cache results to pass a latency objective when the contract
  says reads reflect the latest writes; an index kept in the store and
  updated under the same lock by every writer is the safe shape.
- Adding a dependency is a decision, not an optimisation: check the
  ADRs first; most wins are in the standard library.
- A shared machine perturbs timings. Start your own server on a port
  you confirmed free, send requests only to it, stop only the process
  ids you started, and never kill by name.
- A 40% win on a path that runs once a day is not the win the user
  asked for. Weight by how often the condition happens.
- Local numbers are not production numbers. Scale them with the sizing
  docs if you must, label the scaling, and never report a local p95 or
  a "no more OOMKills" as observed in production.
- Never optimise from a flame graph the engineer described in chat.
  The file is in `.scratch/perf/` or the profile step did not happen.
