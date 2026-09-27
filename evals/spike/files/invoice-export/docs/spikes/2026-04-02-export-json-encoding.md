# Spike: export-json-encoding

Date: 2026-04-02   Timebox: 2 h, used 1.5 h
Stopped because: answered
Location: `.scratch/spike-export-json-encoding/` (never merged)

## Question

Is encoding/json fast enough to render the invoice export at the
50,000 row cap within the 2 s target?

## Answer

yes: 50,000 rows built and encoded in 41 ms (median of 5 runs).

## Findings

| Time (UTC) | Finding | Evidence |
| --- | --- | --- |
| 10:20 | `export.Build` at 50,000 synthetic rows takes 41 ms | `go test -bench BuildExport -benchtime 5x` -> 41.2 ms/op |
| 10:55 | `json.Marshal` is 29 ms of the 41 ms; row mapping is the rest | cpu profile, `go tool pprof -top` |

Measured on: laptop (10 cores, GOMAXPROCS unset)

## Recommendation

adopt: keep encoding/json and the in-memory document.

Reasoning: the export is 50 times inside the target at the cap. Revisit
if the cap is raised or if per-row processing is added to Build.

## Follow-up

- Task: none
- ADR needed: no
