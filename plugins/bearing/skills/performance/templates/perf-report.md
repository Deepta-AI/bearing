# Performance: <symptom>

<!-- Template guidance: the record of one optimisation: the symptom as a
     metric under a condition, a before and an after from the same
     command, the profile that pointed at the cause, and the one change
     between them. The engineer who reviews the change reads it, and so
     does whoever repeats the measurement months later. No number, no
     optimisation: a report without both measurements is not finished.
     Delete each comment when you fill its section. -->

| Field | Value |
| --- | --- |
| Metric | <p95 latency / cpu / heap / lcp / startup> |
| Condition | <load, data size, device, network, build type> |
| Objective | <number and the file it comes from, for example docs/slo.md> |
| Production size | <numbers and the file they come from> |
| Date | <YYYY-MM-DD> |
| Base commit | <sha the before was measured on> |
| Change | <uncommitted on branch X; the engineer commits> |
| Task | <KEY or none> |

## Measurement

<!-- What: the before and after runs from the exact same command, their
     spread, and the median delta.
     Good: the command is copied verbatim and the sample size sits next to
     every number (three runs of ten requests is not a p95); the build,
     data size and warmup are stated in Condition; an after median inside
     the before run's spread is called noise, not a win.
     Example: | Before | `hyperfine -r 3 'curl -s localhost:8080/orders'`
     | 3 | 412 ms | 431 ms | 455 ms | -->

| | Command | Runs | Min | Median | Max |
| --- | --- | --- | --- | --- | --- |
| Before | `<exact command>` | N | | | |
| After | `<same command>` | N | | | |

Delta (median): <Z%>. Noise band from the before runs: <min..max>.
Against the objective: <met with margin / not met, because ...>.
Measured on: <machine, local server or benchmark, data size>; production not observed.

## Profile

<!-- What: the profiler run under the same condition, its artefact path
     and the top frames by self time.
     Good: the artefact is a file in .scratch/perf/, never a flame graph
     described in chat; at least five frames with their share; the note
     says when the widest frame is the runtime (GC, event loop, JSON) and
     names the caller one level up; for memory, two heap profiles minutes
     apart, diffed.
     Example: | encoding/json.(*decodeState).object | 31% | 38% | called
     per row by orders.Scan, one level up | -->

- Tool: <pprof / py-spy / --cpu-prof / clinic / Lighthouse / macrobenchmark / Instruments>
- Artefact: `.scratch/perf/<file>` (not committed; regenerate with the command above)
- Top frames by self time:

| Frame | Self | Total | Note |
| --- | --- | --- | --- |
| | | | |

## Hypothesis and change

<!-- What: one hypothesis named as a frame and a cause, and the smallest
     change that tests it.
     Good: a single cause (N+1 query, allocation in a hot loop, missing
     index, synchronous IO on the request path, lock contention and so
     on); the change keeps behaviour, with the make check test count; a
     behaviour change is a feature for start-task, not this report.
     Example: "orders.List: N+1 query, one SELECT per line item. Change:
     one query with an IN list in internal/orders/repo.go. Files: 1.
     Tests: 214 passed." -->

<frame>: <cause>. Change: <one paragraph>. Files: <list>. Tests: N passed.

<!-- Repeat this paragraph for each change, each with its own measured
     delta and the proof the output is unchanged (byte-identical output at
     the production size, near-miss tests for a rewritten check). -->

## Not tried

<!-- What: the other hypotheses the profile suggested, one per line, and
     why each waits.
     Good: each names a frame and a cause like the one tried, and why it
     is second (smaller share, rarer path); "none" only when the profile
     showed nothing else worth testing.
     Example: "- json.Marshal in the response writer: 9% self; waits
     until the query fix is measured." -->

- <next hypothesis and why it waits>

## How to repeat

<!-- What: the numbered steps a stranger follows to get the same numbers.
     Good: the commit, build type, seed data and data size first, then the
     measurement and profile commands copied exactly from above; nothing
     depends on a warm cache the reader cannot recreate.
     Example: "1. git checkout 3f2a1bc; make db-seed ROWS=50000; go build
     -o bin/api ./cmd/api" -->

1. <checkout, build, seed data>
2. <the measurement command>
3. <the profile command>
