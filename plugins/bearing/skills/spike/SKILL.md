---
name: spike
description: 'Runs a timeboxed spike: a yes, no or number question, a timebox and stop condition, throwaway code never merged, a written recommendation. Use when asked to "spike this", "investigate whether" or "prototype to find out".'
argument-hint: "<name> \"<question>\" [--hours 4] [--branch]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(ls:*), Bash(mkdir -p:*), Bash(date:*), Bash(printenv:*), Bash(git status:*), Bash(git branch:*), Bash(git switch -c:*), Bash(git log:*), Bash(git diff:*), Bash(git show:*), Bash(git check-ignore:*), Bash(git restore:*), Bash(git checkout --:*), Bash(git clean -n:*), Bash(rm -r .scratch/spike-:*), Bash(rm .scratch/spike-:*), Bash(make check:*), Bash(make test:*), Bash(go run:*), Bash(go test:*), Bash(go tool pprof:*), Bash(go version:*), Bash(GOMAXPROCS=1 go test:*), Bash(GOMAXPROCS=1 go run:*), Bash(env:*), Bash(taskset:*), Bash(systemd-run --user --scope:*), Bash(/usr/bin/time:*), Bash(node:*), Bash(pnpm exec:*), Bash(uv run:*), Bash(python3:*)
---

# spike

A spike buys an answer with a fixed amount of time. The question is
written before the code, every number it depends on is taken from the
code, the measurement is made under the conditions the answer is for,
and the only thing that survives is the document.

Not this: `systematic-debugging` for a bug with a symptom;
`tech-decision` for a choice the options already answer.

## Inputs

- name: `$1`, kebab-case; if absent, derive it from the request.
- question: `$2`, or the request. Rewrite it yourself into one whose
  answer is yes, no or a number against a threshold ("can the export
  of the largest allowed tenant build in under 2 s in the pod?" rather
  than "look into the export"). Never wait on the user for it: write the
  rewrite and any assumption into the doc and go on.
- timebox: `--hours`, default 4. Start written as `date -u +%FT%TZ`.
- location: `.scratch/spike-<name>/` (created; `git check-ignore -q
  .scratch` tells whether it is ignored); `--branch` creates
  `spike/<name>` with `git switch -c` instead. The state file (question,
  start, stop condition, each finding with its UTC time) lives in the
  location, so nothing else is created outside it but the doc.
- prior work: `docs/spikes/*.md`, `docs/adr/*.md` and any capacity,
  sizing or decision doc, grepped for the subject nouns.
- tracker: `printenv BEARING_TRACKER`, else the `BEARING_TRACKER` line in
  `~/.config/bearing/bearing.env`; `none` or unset: the follow-up is a
  line in the doc with the note `tracker: none`; otherwise the
  `tracker-sync create` command is printed, never run here.
- template in this skill: `templates/spike.md`.

## Steps

1. Take the operative inputs from the code, not the docs. The size
   (row cap, batch size, payload limit: the constant or config the code
   enforces), the runtime (`go version`, the Dockerfile base image,
   `.nvmrc`, `engines`, CI image), the deployment's CPU and memory limits
   and how many requests share one instance, and how the process is
   really started (entrypoint, cron line, wrapper script). Where a doc
   and the code disagree, the code wins and the disagreement is a
   finding. Write "answered looks like" (the number and its threshold at
   that size, or the artefact that must exist) and the stop condition.
2. Read prior work and decide whether it still holds. For each earlier
   spike or ADR on the subject: what size, version and code it was
   measured on; `git log --oneline --since=<its date> -- <the files it
   measured>` for what changed since; its own revisit condition. A stale
   result is a finding with the reason; its number is never reused as
   evidence. Recheck an ADR's stated reasons against today's versions
   instead of repeating them, and keep the constraints of any ADR still
   Accepted. Earlier documents are not rewritten; a link line is fine.
3. Baseline before any code: run the repository's own check (`make
   check` or its equivalent) and write the result. List what cannot run
   here (dependency not installed and no network, no Docker, no
   production data or database) so the doc can say it later.
4. Investigate inside the location only, with the smallest code that
   answers the question. Measurement discipline:
   - Measure at the operative size. A smaller size extrapolated must be
     labelled as extrapolation; costs are often not linear (GC, cache
     misses, a quadratic loop, work repeated per item).
   - Measure under the deployment's limits. CPU: 500m is half a core
     under a CFS quota, so pin to one core (`GOMAXPROCS=1`, `taskset -c
     0`, or `systemd-run --user --scope -p CPUQuota=50%`) and say how the
     laptop maps to the pod. Memory: peak RSS or heap (`/usr/bin/time
     -v`, `runtime.ReadMemStats`, `--heapsnapshot`) against the limit,
     multiplied by the concurrency the repo states. A latency target at
     p99 is not shown by one run: repeat (five or more) and give median
     and worst.
   - Profile before attributing cost (`go test -cpuprofile` then `go tool
     pprof -top`, `node --cpu-prof`, `python3 -m cProfile`), then time
     each large piece alone at the operative size. The change the
     question assumes (a faster library) is often not where the time
     goes; the spike tests that assumption first.
   - For "can we replace X with Y": grep every call of X's API in the
     code (not the ones you remember) and run each against Y on this
     machine, naming the version. Then look for what differs silently:
     defaults (timeouts, numeric types, input the old one tolerated,
     transaction semantics), anything new Y prints and who reads that
     stream (wrappers, alerting), version pins everywhere the runtime is
     chosen, and whether a workaround reaches every path that starts the
     process, not only the one you ran.
   - Name what the measurement leaves out: the database fetch an
     in-memory store skips, network, disk, production hardware.
   Each finding goes into the state file with a UTC time and its
   evidence (the command and its output line, the number, a path).
   `git status --porcelain` outside the location showing a change is a
   finding: `git restore` it before going on.
5. Check the clock at every finding. At 50 percent with no finding,
   decide without asking: continue only if the next step is already
   known, otherwise stop and write a narrower question. At 100 percent,
   stop whatever the state.
6. Recommend from the findings. Name the change the measurement supports
   and the re-measurement that would confirm it; keep every invariant
   the current code enforces (masking, validation, a test that pins
   behaviour), never trade one away to hit the number; name the risks the
   recommended change brings (new failure modes, changed error
   behaviour, what a client or operator will now see differently).
   A decision written anywhere is marked Proposed, with no decider.
7. Write `docs/spikes/<date>-<name>.md` from `templates/spike.md`:
   question, answer (yes, no, the number, or "not answered: <why>"),
   operative inputs and where each came from, prior work and whether it
   held, findings with evidence, what was tried and discarded, where it
   was measured, not run or not measured, recommendation, the follow-up
   task (the `tracker-sync create --type task --title "<title>"`
   command, or `tracker: none`) and the throwaway note.
8. Clean up and prove it: delete the throwaway (`rm -r
   .scratch/spike-<name>`) unless the doc says where it stays and it
   sits where the build and tests cannot pick it up (never a `*_test.go`
   in a package, a `*.test.js`, or `test_*.py` inside the repo's test
   globs). Run the repository's check again and `git status
   --porcelain`: only the doc is new, no tracked file differs, nothing
   is committed. Print the contract.

## Output contract

```
## Spike: <name>
Question: <one line>
Timebox: <h> h, used <h> h (<start> to <end> UTC)   Stopped: answered | timebox | blocker
Answer: yes | no | <number and unit> | not answered (<why>)
Operative inputs: <size from code, runtime, CPU/memory limits, concurrency>
Prior work: K found, <held | stale: why>
Findings: N (each with evidence)
Measured on: <laptop, pinned to N cores | staging | prod-like>
Not run: <what could not run here and what rests on reading code>
Recommendation: adopt | reject | narrower spike ("<question>")
Follow-up: "<title>" (tracker-sync create --type task ... | tracker: none)
Throwaway: deleted | .scratch/spike-<name>/ | spike/<name> (engineer: git branch -D spike/<name>)
Check: <repo check before> / <after>; git status: only <doc path>
Path: docs/spikes/<date>-<name>.md
```

## Gotchas

- A spike that ships its code is a feature without tests. The code is
  thrown away; the doc and the follow-up are what survive.
- The docs lag the code. A capacity table, a README or an old spike
  quoting a limit is a claim; the constant the code enforces is the fact.
- An old spike's "yes" answers the old question: other size, other code,
  other version. Check what changed since and its revisit condition.
- Laptop numbers are not pod numbers: spare cores absorb GC and any
  parallel work, and a half-core quota throttles even one thread to half
  speed. A memory figure without the concurrency per pod is half an
  answer.
- The suspected culprit is a hypothesis. Profile first; the spike that
  confirms the assumption without measuring it answers nothing.
- "Could not run it" is a result, not a gap to paper over. Say what was
  read rather than run, so nobody mistakes it for a tested claim.
- Throwaway code inside the repo's build or test globs breaks the next
  person's `make check`; a spike that leaves the check red did harm.
- The timebox is the point. "One more hour" is how a spike becomes a
  week; the 50 percent check exists to catch that.
- A spike that answers a different question is recorded as "not
  answered" for the question asked, with what was learnt beneath.
