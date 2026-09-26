# One agent, bounded tasks, or parallel subagents

Answer before splitting any work. Ask the questions in order; the first
that fits decides.

## 1. Is the job judging? Use a read-only agent.

Review, verification, critique and mapping change nothing, so the agent
should not be able to. Use `explorer` to map code, `reviewer` to
review a diff, `verifier` to test one finding, and `critic` to
argue against a PRD, HLD or LLD. They hold Read, Grep and Glob only.

## 2. Does each step depend on what the last one found? One agent.

A bug hunt, a refactor across files, a design that settles as you read:
step 2 depends on step 1, and the context built so far is the asset.
Splitting it means each new agent rebuilds that context and loses what
the last one noticed. Keep it in one session; use `session-handoff` if it
runs past one.

## 3. Is it long but divisible into checkable steps? Bounded tasks in sequence.

The work divides into steps, and each step has an output you can check
(a test passes, a file exists, a gate prints its count). Run them one
after another, a fresh context per task and a check between tasks, so a
bad step stops before the next one builds on it. The engines:

- Superpowers `writing-plans`, then `subagent-driven-development`: a plan
  of small tasks, one fresh subagent per task, a review after each.
- GSD `/gsd-plan-phase`, then `/gsd-execute-phase`: when the work spans
  sessions and needs its phases tracked.

## 4. Parallel subagents only when all four hold

1. The pieces are independent: no piece needs another's result.
2. They touch different files. Shared files stay with the lead, who
   merges after the agents return.
3. Each piece has its own check, run by the agent before it reports.
4. Results come back as conclusions, not file dumps: a verdict, a path
   and line, a count. The lead's context is the scarce resource.

If any one fails, go back to 2 or 3. Examples that pass all four:

- one `verifier` per Critical or High finding, as `branch-review` does;
- one search per question, each returning the answer and its location;
- new templates or skills built in separate folders while the lead keeps
  the shared files (Makefile, docs, the changelog) and edits them once.

The engine is Superpowers `dispatching-parallel-agents`; GSD
`/gsd-execute-phase` runs independent plans of a phase in parallel waves.

## Cost

Every agent pays to rebuild context: it reads the files, the rules and
the task again. Parallel agents multiply that cost. Pay it for one of two
reasons only:

- wall-clock time matters and the pieces are big enough to save it;
- independence is the point, as in verification, where an agent that has
  not seen the author's reasoning is harder to talk into agreeing.

Otherwise one agent, or bounded tasks in sequence, is cheaper and loses
less.
