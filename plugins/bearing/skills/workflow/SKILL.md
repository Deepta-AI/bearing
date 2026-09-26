---
name: workflow
description: 'Says where the work stands (repository, branch, diff) and which skill or step comes next. Use when asked "what should I do next", "which skill do I use", "how do we work here" or "what is in flight".'
allowed-tools: Read, Grep, Glob, Bash(git status:*), Bash(git branch:*), Bash(git log:*), Bash(git rev-parse:*), Bash(ls:*), Bash(wc -l), Bash(bash *bin/brg-state-path*), Bash(python3 *skills/session-handoff/scripts/progress.py*)
---

# workflow

Answer three questions: where are we, what comes next, which skill does it.
Asked what is in flight, answer from the progress index. Asked whether to
run one agent, bounded tasks or parallel subagents, answer from
`references/agent-split.md`.

The map, one skill per stage; the full map is
`docs/WORKFLOW.md`:

| Stage | Skill |
| --- | --- |
| Pressure-test | `/office-hours`, `/plan-ceo-review` (gstack) |
| Spec | Superpowers `brainstorming`, `prd`, `backlog` |
| Plan | Superpowers `writing-plans`, `/plan-eng-review`; multi-session: GSD `/gsd-plan-phase` |
| Set up | `new-repo`, `onboard-repo`, `company-attribution`; a codebase you inherited: the inherited codebase flow (`onboard-repo`, `explain-codebase`, `docs-drift`, a baseline, characterisation tests) |
| Start | `start-task <ID>` |
| Choose | `tech-decision` (options, recommendation, user decides) |
| Record | `adr`, `high-level-design`, `low-level-design` |
| Design | `ux-flows`, `/design-consultation`, `design-directions`, `design-system`, `screen-design` |
| GenAI | `genai-design`, then `rag` or `llm-agent`, `llm-gateway`, `llm-eval` |
| Build | Superpowers `test-driven-development`; `db-migration` |
| Debug | Superpowers `systematic-debugging`, `/investigate` |
| Verify | `test-run`, `test-heal`, `docs-drift`, `definition-of-done`, `branch-review` (gstack `/review` plus independent verification), `/cso` |
| Ship | `merge-request`, `tracker-sync`, `task-report`; release: `release`, then claude-security and `vapt-report` |
| Operate | after the engineer deploys: `verify-deploy`, then gstack `/canary` on prod; `runbook`, `incident`, `postmortem` |
| Pause | `session-handoff` (local state, and the shared `docs/progress/<ID>.md`) |

## Inputs

- Repository: `git rev-parse --show-toplevel`; if not a git repository
  (or no commits yet), the map still prints, the stage is "Start", and
  the next action is `new-repo <stack> <Name>` for an empty directory
  or `onboard-repo --stack <id>` for code without the standard files, then
  `git init` and `start-task`.
- Branch, changes and recent commits: `git branch --show-current`,
  `git status --porcelain | wc -l`, `git log --oneline -5`; if absent,
  each prints `none`.
- Stack: `package.json` (react, expo), `go.mod`, `pyproject.toml`,
  `app.json`, `build.gradle.kts`, `Package.swift`, `*.tf`; if none,
  `unknown` and the stage cannot pass Spec.
- Task id: the branch name (`[A-Z][A-Z0-9]*(-[0-9]+)+`); if absent, `none`.
- Handoff: `.bearing/state/<branch with / as _>.md` (`bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-state-path"` prints it); if absent, nothing to resume. It is local to this machine.
- In flight: the committed progress files, the shared record across
  engineers and clones, read on every branch with
  `python3 "${CLAUDE_PLUGIN_ROOT}/skills/session-handoff/scripts/progress.py" index --open --refs`
  (the last line counts tasks by status). Exit 1 with "0 progress files"
  means no task has one yet: say `in flight: none recorded`, never "nothing
  in flight".
- Gate status: the Stop hook's last `make check` result or a Makefile
  `check` target; if neither exists, "gate: none (onboard-repo adds one)".

## Steps

1. Detect the state in one batch as in Inputs.
2. Read the handoff file if it exists; it holds the last stop point. Run
   the in-flight index as in Inputs; for "what is in flight", print its
   table and last line, name blocked tasks first, and stop there.
3. Place the work on the map below by asking, in order: is there a
   repository; is there a task branch; is the request clear enough to
   code; is there a plan; is code written; does `make check` pass; is
   there an MR.
4. Print the map with the current stage marked, then the single next action
   and its skill, then the two after that. Keep it under 25 lines.

## Output contract

```
workflow
repo: <name | none> (<stack | unknown>)   branch: <branch | none>   task: <ID or none>   changes: N
stage: <stage>
in flight: <the index's last line | none recorded>
next: <one action>  ->  <skill>
then: <action> -> <skill>; <action> -> <skill>
```

## Gotchas

- If no task branch exists and the branch is `main` or `develop`, the next
  action is always `start-task`, whatever else is true.
- If `make check` has not passed since the last edit (the Stop hook sends
  the session back once to say so), "Verify" comes before "Ship" no matter
  how ready it looks.
- Outside a repository the answer is still useful: the map plus "start
  with `new-repo` or `onboard-repo`". Never say "nothing to do".
- Do not run any skill from here. Name it and stop.
