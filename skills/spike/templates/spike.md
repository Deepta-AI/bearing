# Spike: <name>

<!-- Template guidance: the only thing a timeboxed spike keeps. The code is
     thrown away; this answer, its evidence and the follow-up are what the
     team reads when they decide. Every comment says what goes there (What),
     what a strong entry has (Good) and an example (Example). Delete each
     comment when you fill its section. -->

Date: <YYYY-MM-DD>   Timebox: <h> h, used <h> h (<start> to <end> UTC)
Stopped because: answered | timebox | blocker (<what>)
Location: `.scratch/spike-<name>/` | branch `spike/<name>` (never merged)
Prior spikes: <links | none>

## Question

<!-- What: the question the spike was run to answer, in one line, written
     before any code.
     Good: its answer is yes, no or a number; "look into X" is not a
     question. A second spike on one subject is narrower and links the first.
     Example: "Can the Postgres LISTEN/NOTIFY queue deliver 500 jobs a second
     on one db.t3.medium?" -->

## Answered looks like

<!-- What: what counts as answered, fixed before the investigation starts.
     Good: a number with its threshold, or an artefact that must exist (a
     passing call, a rendered screen, a build that links).
     Example: "p99 enqueue-to-start under 200 ms at 500 jobs/s for 10 minutes." -->

## Answer

<!-- What: the answer to the question as asked.
     Good: one of yes, no, a number with its unit, or "not answered: <why>".
     A spike that answered a different question is "not answered" here, with
     what was learnt under Findings; zero findings is a valid not answered.
     Example: "no: p99 reached 1,340 ms at 500 jobs/s (finding at 14:52)." -->

yes | no | <number and unit> | not answered: <why>

## Findings

<!-- What: every finding in the order it landed, with its UTC time and
     evidence, then where it was measured.
     Good: evidence is the command and its output line, a number or a path a
     reader can re-run; laptop numbers are named as laptop numbers.
     Example: "14:52 | p99 climbs past 1 s above 350 jobs/s | `go run
     ./bench -rate 500` -> p99=1340ms, .scratch/spike-pg-queue/run3.txt" -->

| Time (UTC) | Finding | Evidence |
| --- | --- | --- |
| <hh:mm> | <what was learnt> | `<command>` -> <output line>, <number>, <path> |

Measured on: laptop | staging | prod-like (<details>)

## Tried and discarded

<!-- What: approaches started and dropped inside the timebox.
     Good: each says why it was dropped, so the next spike does not retry it.
     Example: "- Batching NOTIFY per transaction: cut p99 by 8% only; the
     lock on the jobs table was the limit." -->

## Recommendation

<!-- What: adopt, reject, or a narrower spike with its question written out,
     then two sentences of reasoning.
     Good: the reasoning follows from the answer and findings above, not
     from preference.
     Example: "reject. Reasoning: the queue misses the target by 6x on the
     instance we run; a managed queue removes the table lock entirely." -->

adopt | reject | narrower spike: "<the narrower question>"

Reasoning: <two sentences>

## Follow-up

<!-- What: the task that carries the result forward, and whether an ADR is
     needed.
     Good: a task title someone can pick up; the tracker-sync create command
     is printed, never run, or the line reads tracker: none.
     Example: "- Task: \"Move background jobs to SQS\" (ENG-412)" -->

- Task: "<title>" (<TASK-ID> | `tracker-sync create --type task --title "<title>"` | tracker: none)
- ADR needed: yes (`adr <title>`) | no

## Throwaway

<!-- What: where the spike code lives and how it goes away.
     Good: the code is never merged; the branch delete command is here for
     the engineer to run after this document is committed.
     Example: "Branch spike/pg-queue: engineer runs git branch -D
     spike/pg-queue after this doc merges." -->

The spike code is not merged. `.scratch/spike-<name>/` is ignored; the
branch is deleted with `git branch -D spike/<name>` once this document
is committed.
