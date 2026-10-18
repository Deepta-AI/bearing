---
name: autopilot
description: 'Runs unattended from one requirement statement to a prepared merge request, taking each decision as Proposed for review; never pushes. Use when asked to "autopilot this", "run it end to end" or "build this unattended".'
argument-hint: "\"<requirement statement>\" [--resume]"
allowed-tools: Read, Write, Edit, Grep, Glob, Skill, Agent, Bash
---

# autopilot

One statement in, one prepared merge request out, with nobody answering
questions in between. Every decision a stage would put to the user is taken
with the recommended option, written as Proposed and listed in one
digest the user reviews at the end. The run never pushes, merges or
deploys: the guard, the sandbox and, where the repository has it, the
pre-push hook stop it if it tries, and the last stage prints the push command for the engineer.

`bin/brg-autopilot` holds the order, the gates and the digest. The
skill does the work; the script decides whether a stage is done, from
what is on disk, never from what the model says it did.

## Inputs

- statement: `$ARGUMENTS`; with `--resume`, the open run in
  `.bearing/state/autopilot.json`. Neither: stop with "give the
  requirement as one statement".
- directory: the working directory. Empty or not a repository: the
  repo stage creates one with `new-repo`. An existing repository
  gets only what the gates read, nothing of the standard it did not ask
  for (step 1a); `onboard-repo` is the engineer's own decision, never a
  side effect of a feature request.
- stages, gates and state: `python3 "${CLAUDE_PLUGIN_ROOT}/bin/brg-autopilot"`
  (start, next, done, fail, decision, profile, repos-request, report,
  status, stages).
- the stage skills: loaded with the Skill tool, or read from
  `${CLAUDE_PLUGIN_ROOT}/skills/<name>/SKILL.md` when the Skill tool
  refuses. Every skill `next` names is run, each in turn. Detail:
  references/stage-skills-and-scope.md
- scope: `lean` or `full`, printed by `status` and by each gate. Lean writes
  only what a reviewer of this change reads. Detail:
  references/stage-skills-and-scope.md

## Steps

1. Start or resume: `python3 "${CLAUDE_PLUGIN_ROOT}/bin/brg-autopilot" start "<statement>"`,
   or `status` then `next` on `--resume`. Print the run id. Detail:
   references/repo-stage.md
2. Loop until `next` says every stage is done or a stage is blocked:
   1. `next` names the stage, its skill and its gate.
   2. Run the stage's skill in auto mode (below).
   3. `done <stage>`. On "gate not met", fix what it names and run
      `done` again; when the same stage cannot be fixed, `fail <stage> "<why>"`,
      which allows three attempts before the stage is blocked.
3. Auto mode, for every stage: wherever a skill says to ask a question, to
   stop and wait, or to confirm, take the option the skill recommends and
   go on, and record the choice with `decision`. Detail:
   references/auto-mode-and-profile.md
4. The product profile, at the end of the decide stage: `profile --ui yes|no --data yes|no --api yes|no --deploy yes|no [--llm yes|no] [--ui-stack <stack>] [--scope lean|full] --why "<reason>"`.
   Detail:
   references/auto-mode-and-profile.md
5. Tools go through the repository's make targets; never call a package
   manager directly. Detail: references/auto-mode-and-profile.md
6. Before the build, in lean scope: the design note, then test-cases. In
   full scope: architecture, design, repos, ux, then contract (the data
   model and API from the screens' data needs). Detail:
   references/design-stages.md
7. Build is test first, story by story, in the order of the backlog. Read
   the traps in references/reviewer-checks.md first. Detail:
   references/build-and-after.md
8. After the build: test-automation, the LLM stages when the profile says
   llm, then `test-run --changed` (the test_run stage), and design-critique
   until the bar holds. Detail: references/build-and-after.md
9. Review is `branch-review --unattended`; fix every Critical and High it
   confirms, record each fix as `<n> <sha>` in `.scratch/review/<slug>/fixed.txt`,
   then `make check` again; `definition-of-done --unattended` includes the
   smoke run and the full test run. Read references/reviewer-checks.md again
   before dod. Detail: references/review-smoke-and-mr.md
10. The mr stage: `merge-request` prepares the description; `report` writes
   `docs/autopilot/<run>.md`; commit it, and let that commit be the last
   write (`git status` clean after it); paste its decisions table into the
   description with the exact push command under it, and print the same
   command in the last message. Do not run it. Detail: references/review-smoke-and-mr.md
11. Blocked or finished, the last message is the report: stages done,
   the decisions to review, what is not done and why, and the push
   command when the MR is ready.

## Output contract

```
## Autopilot <run>: <statement>
Stages: <n> of <N> done   Blocked: <stage (why)> | none
Decisions to review: N (all Proposed)  docs/autopilot/<run>.md
Profile: ui=<yes|no> data=<yes|no> api=<yes|no> deploy=<yes|no>
| Key | Choice | Alternatives | Why |
Branch: <branch>  Commits: N  make check: passed | not passed
MR description: .scratch/mr-<id>.md
Push (yours): git push -u origin <branch>
Not done: <list> | none
```

## What a reviewer checks that the tests do not

A strong run and a merely passing one differ here, not in the documents.
Read before the first line of code. Detail: references/reviewer-checks.md

## Gotchas

- The digest is the product as much as the code: a decision taken and
  not recorded is a decision the user cannot review. Record it when it
  is taken, not at the end.
- Empty sandbox placeholders at the root (`.mcp.json`, `.vscode`,
  `.idea`, `.claude` files and the like) are not work: the gates ignore
  them and the pre-commit hook refuses them. Leave them alone; do not ask
  about them.
- A gate that fails three times blocks the stage; the run stops there
  and reports, rather than building on a stage that did not hold.
- Auto mode answers questions; it does not widen scope. Build what the
  statement and the stories ask, nothing more. The measure is the diff:
  outside the run's own documents (docs/product, docs/adr, docs/design,
  docs/architecture, docs/testing, docs/autopilot) every changed line
  serves the statement. A reviewer finding in code the statement did not
  touch is reported, not fixed here, unless the change itself caused it.
- Long runs survive compaction through the snapshot hook and resume
  from `.bearing/state/autopilot.json`; `--resume` continues at the
  next stage. `<N>` in the output is the line count of `stages`.
- Unattended from a script: `python3 bin/brg-autopilot launch "<statement>"`
  runs `claude -p` in the directory with the repository's settings, so
  the sandbox and the guard apply.
