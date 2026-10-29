---
name: workflow
description: 'Says where the work stands (repository, branch, diff) and which skill comes next. Use when asked "what should I do next" or "which skill do I use".'
allowed-tools: Read, Grep, Glob, AskUserQuestion, Bash(git status:*), Bash(git branch:*), Bash(git log:*), Bash(git rev-parse:*), Bash(git rev-list:*), Bash(git diff:*), Bash(git show:*), Bash(git ls-tree:*), Bash(git for-each-ref:*), Bash(git merge-base:*), Bash(git grep:*), Bash(make -n:*), Bash(make check:*), Bash(ls:*), Bash(wc -l), Bash(bash *bin/brg-state-path*), Bash(bash *bin/brg-session*), Bash(bash *bin/brg-config*), Bash(bash *bin/brg-learn*), Bash(python3 *skills/session-handoff/scripts/progress.py*)
---

# workflow

Answer three questions: where are we, what comes next, which skill does it.
Asked what is in flight, answer for the whole team. Asked whether to run one
agent, bounded tasks or parallel subagents, answer from
`references/agent-split.md`.

The job is a status read, and a status read is only as good as its
sources. Progress records, handoff notes and branch names are claims
written by someone who wanted to be done; the code, the tests and git
history are the evidence. Every line of the answer comes from the
evidence, and where a record disagrees, say so and name the record as
stale. A strong generalist reads the records and summarises them; the
value here is catching where they are wrong.

## With no argument: the menu

Only when called with no argument and no question. With an argument or a
question (what is in flight, which skill, one agent or several), skip this
section and answer as below.

1. Run `bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-session" resume` and read the
   checkpoint, the last skills and the next flow step. Its own "ask whether
   to continue" line is input only: the one ask is this menu's. On a trunk
   or release branch with no history it prints nothing: use the repository
   read in Inputs instead, and lead with `start-task` when there is no
   task branch.
2. Run `bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-learn" top --skills "<candidate skills>" --n 3`
   and fold any learnings into the reasons; if it prints nothing (learning
   off or no jq), carry on.
3. Lead with the two or three best next skills, each with one line of
   reason taken from that output or the repository (uncommitted files with
   no check: `definition-of-done`; next flow step: that skill; a stale
   progress record: `session-handoff`).
4. Then the stage table below.
5. Ask with AskUserQuestion which to run (the first is the recommendation).
   Never run one without an answer; this skill stays read-only. Questions
   follow `${CLAUDE_PLUGIN_ROOT}/references/console.md`.

The map, one skill per stage; the full map is `docs/WORKFLOW.md`:

| Stage | Skill |
| --- | --- |
| Pressure-test | `/office-hours`, `/plan-ceo-review` (gstack) |
| Spec | Superpowers `brainstorming`, `prd`, `backlog` |
| Plan | Superpowers `writing-plans`, `/plan-eng-review`; multi-session: GSD `/gsd-plan-phase` |
| Set up | `new-repo`, `onboard-repo`, `company-attribution`; a codebase you inherited: `onboard-repo`, `explain-codebase`, `docs-drift`, a baseline, characterisation tests |
| Start | `start-task <ID>` |
| Choose | `tech-decision` (options, recommendation, user decides) |
| Record | `adr`, `high-level-design`, `low-level-design` |
| Design | `ux-flows`, `design-directions` (calls impeccable when installed), `design-system`, `screen-design`, then `data-model` and `openapi-spec` from the screens' data needs |
| GenAI | `bearing-genai:genai-design`, then `bearing-genai:rag` or `bearing-genai:llm-agent`, `bearing-genai:llm-gateway`, `bearing-genai:llm-eval`, `bearing-genai:model-routing` |
| Site | a landing page or marketing site: the site flow (`start-task --flow site`); `screen-design`, `accessibility`, `performance`, `branch-review` |
| Build | Superpowers `test-driven-development`; `db-migration` |
| Debug | Superpowers `systematic-debugging`, `/investigate` |
| Test | `test-run --changed`, `test-heal`, gstack `/qa`, `load-test` |
| Review | `branch-review` (gstack `/review` plus independent verification), gstack `/cso` |
| Verify | `definition-of-done`, which runs every suite, `docs-drift` |
| Ship | `merge-request`, `tracker-sync`, `task-report`; release: `release`, then claude-security and `vapt-report` |
| Operate | after the engineer deploys: `verify-deploy`, then gstack `/canary` on prod; `runbook`, `incident`, `postmortem` |
| Pause | `session-handoff` (local state, and the shared `docs/progress/<ID>.md`) |

## Inputs

- Repository: `git rev-parse --show-toplevel`; if not a git repository
  (or no commits yet), the stage is "Start" and the next action is
  `new-repo <stack> <Name>` for an empty directory or
  `onboard-repo --stack <id>` for code without the standard files, then
  `git init` and `start-task`.
- Branch and changes: `git status --porcelain --branch` (names every
  modified and untracked path, and ahead/behind against the upstream).
- Remote picture: `git for-each-ref --format='%(refname:short) %(upstream:short) %(upstream:track) %(committerdate:short) %(authorname)' refs/heads refs/remotes`.
  Remote-tracking refs are as of the last fetch; this skill never fetches,
  so say that in the answer. The Git host (merge requests, CI) and the
  tracker are not read here; say that too rather than guess.
- Base: the default branch is `origin/HEAD` (usually `origin/main`), not the
  local `main`, which may never have been pulled.
- Stack: `package.json`, `go.mod`, `pyproject.toml`, `app.json`,
  `build.gradle.kts`, `Package.swift`, `*.tf`; if none, `unknown`.
- Task id: from the branch name (`[A-Z][A-Z0-9]*(-[0-9]+)+`).
- Flow, read before picking one: `bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-config" get flow`.
  `site` means the site flow on every branch but a fix branch (bugfix);
  empty means choose from the branch and the request. The next flow step is
  `bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-session" next-step`, which skips
  `new-repo` once the repository has commits and `design-system` once
  `docs/design/tokens.json` exists.
- Handoff: `.bearing/state/<branch with / as _>.md`
  (`bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-state-path"` prints it); local to
  this machine, often newer than the committed record.
- Progress records:
  `python3 "${CLAUDE_PLUGIN_ROOT}/skills/session-handoff/scripts/progress.py" index --refs`
  reads `docs/progress/*.md` from every local and remote-tracking branch
  and keeps the newest per task. It reports what the records say, nothing
  more: it does not know a branch was merged, a blocker was resolved or a
  test exists. Exit 1 with "0 progress files" means none recorded, not
  nothing in flight.
- Gate: a Makefile `check` target. Read it with `make -n check` first; run
  `make check` when it only builds and tests (no formatter writing files,
  no network, no containers). If it would write or cannot run here, say
  "not run" and why. Never say a gate passed without running it.

## Steps

1. Detect the state in one batch as in Inputs. Note the date of the newest
   commit on any ref: "stale" is measured against that, not the clock.
2. One task (a resume, "where did I leave X", "can I open the MR"):
   a. Read the handoff and `docs/progress/<ID>.md`. List every claim they
      make: each Done item, each test named, the status, the Next.
   b. Diff the branch against its base: `git diff <base>...HEAD --stat`
      for committed work, `git status` and `git diff` for uncommitted.
      Where the base is behind `origin/main`, list what `origin/main`
      gained (`git log HEAD..origin/main --stat`) and check it against the
      branch: a migration number, a renamed function, a changed config.
   c. Check each claim against the code: a named test exists
      (`git grep -n 'func TestX\|test("x'`), a Done item has code in the
      diff (a commit that only touches the record is not the work), a
      stub or TODO sits behind a call that looks finished.
   d. Check each acceptance criterion word by word, not the feature name.
      "Changes nothing", "every", "exactly once", "never" are claims about
      all paths: a check and a write under separate locks or transactions
      (read, check, then write) lets two concurrent requests both pass the
      check; an error that is ignored breaks "every". A criterion is met
      only when code does it on every path and a test exercises it.
   e. Read the repository's own rules that the diff touches (README,
      `docs/adr/`, CONTRIBUTING): an edited file that the rules say is
      immutable, a number that must be taken at merge time.
   f. For numbered artefacts (migrations, ADRs), compute the next free
      number from `origin/main` and from every open remote branch
      (`git ls-tree -r --name-only <ref> <dir>` for each); two branches
      holding the same number is a collision to flag, not a detail.
   g. Run the gate as in Inputs; report the result and which tests ran,
      and whether any of them exercises the task's criteria. A green suite
      that never touches the change is not evidence the change works.
3. The team ("what is in flight", standup): list every task from the
   index, every branch named for a task, and every task named in a merge
   commit on `origin/main`, then reconcile each:
   - merged: its branch is in `git branch -r --merged origin/main` or a
     merge commit names it; closed, whatever its record says;
   - newer elsewhere: the origin copy of a record beats a local branch
     that is behind it; the index already prefers the newest `Updated`;
   - blocked: read the blocker's source on `origin/main` (the ADR, the
     other task); if it has since resolved, say it can move;
   - unpushed: a local branch with no upstream is invisible to the team;
   - unrecorded: a pushed task branch with no record is still in flight;
   - stale: no commit or record change for weeks before the newest
     activity in the repository; ask whether it is alive;
   - claimed but empty: a Done item with no code on the branch.
   Count only after reconciling; the index's own summary line counts what
   records say and must not be quoted as the answer.
4. Place the work on the recorded flow's map by asking, in order: is there
   a repository; a task branch; a clear request; a plan; code; do the criteria hold in
   the code; does the gate pass; is the branch current with `origin/main`;
   is there an MR. The first "no" is the stage.
5. Write the answer. Change nothing: no record corrected, no rebase, no
   stash, no commit, no fetch. Name the skill for each next step; do not
   run it.

## Output contract

Lead with the answer to the question asked, in the user's terms, then the
evidence, then the next steps. No preamble, no command log.

- One task: a yes or no to what was asked (can I open the MR), then each
  blocker with its file and line or commit, each stale claim in the record
  named as stale, the gate result as run (or "not run"), then one first
  action that can start now and the ordered steps to the MR, each with its
  skill.
- The team: stuck first (blocked, stale, collisions), then moving, then
  records that are wrong but not stuck, then closed tasks in one line. One
  line per task: id, owner, what git shows, the ask. A count, if given,
  matches the lines. Short enough to read out in a standup.
- Close with one line on sources: remote refs as of the last fetch; Git
  host and tracker not checked; gate run or not run.

```
next: <one action>  ->  <skill>
then: <action> -> <skill>; <action> -> <skill>
```

## Gotchas

- On `main` or `develop` with no task branch, the next action for new
  work is `start-task`; a team status question is still answered in full.
- Local `main` behind `origin/main` hides merges, accepted ADRs and new
  migrations. Read files from `origin/main` with `git show origin/main:<path>`.
- A record's Next of "open the MR" is a claim like any other; it is right
  only when every criterion holds in the code, the gate passed and the
  branch is current.
- Never quote a count or summary produced before reconciliation; it will
  contradict your own list.
- Outside a repository the answer is still useful: the map plus "start
  with `new-repo` or `onboard-repo`". Never say "nothing to do".
