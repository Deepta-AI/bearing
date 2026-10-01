---
name: autopilot
description: 'Runs unattended from one requirement statement to a prepared merge request, taking each decision as Proposed for review; never pushes. Use when asked to "autopilot this", "run it end to end" or "build this unattended".'
argument-hint: "\"<requirement statement>\" [--resume]"
allowed-tools: Read, Write, Edit, Grep, Glob, Skill, Agent, Bash
---

# autopilot

One statement in, one prepared merge request out, with nobody answering
questions in between. Every decision a stage would ask the user is taken
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
- the stage skills: loaded with the Skill tool, or, for a command-only skill
  the Skill tool refuses (most Bearing skills: new-repo, prd,
  data-model, openapi-spec, deployment-architecture, ux-flows,
  design-system, screen-design, design-critique, test-cases,
  test-automation, start-task, merge-request and others), read from
  `${CLAUDE_PLUGIN_ROOT}/skills/<name>/SKILL.md` and followed the same way.
  Every skill `next` names is run, each in turn; writing its document
  freehand instead is how the first run skipped the data model, the API
  contract and every design skill while its gate still passed.
- scope: `lean` or `full`, printed by `status` and by each gate. Lean is a
  change to a repository that already had code, or a new product with
  no UI, data, API or deployment (a CLI, a library). Full is everything
  else, and a change that adds a service, a store, an external
  integration or a new UI area (`profile --scope full`, with the reason).
  In lean scope the stage skills are followed for their method, but
  the run writes only what a reviewer of this change reads: the PRD's
  REQ lines for this change, its stories and coverage, one design note
  (`docs/design/<name>.md`: what changes, where, the existing rules it
  follows, what it leaves alone), the risk register and case table, the
  report. No C4 set, tenets, repo plan, HLD, test plan, scenarios, step
  tables, import or question logs, user flows or progress files: a
  12-line search command once came with 25 documents and 1,145 lines,
  and the reviewer failed it for that alone. The documents are sized to
  the diff, not to the template.

## Steps

1. Start or resume: `python3 "${CLAUDE_PLUGIN_ROOT}/bin/brg-autopilot" start "<statement>"`,
   or `status` then `next` on `--resume`. Print the run id.
   1a. The repo stage on an existing repository. The gates read a git
   repository, a Makefile `check` target that records a pass
   (`.bearing/state/.check-passed`), and `.scratch/` and
   `.bearing/state/` kept out of git. Whatever of that is present
   stays as it is; `done repo` passing on the untouched repository is
   the expected case. What is missing is added at its smallest: the
   one recipe line `@mkdir -p .bearing/state && touch
   .bearing/state/.check-passed` at the end of `check`, a `check` that
   runs the repository's own test command when there is none, the two
   ignore lines. No CI, hooks, templates, rules files, AGENTS.md or
   CLAUDE.md, and no rewrite of the build: the first run on a 227-line
   feature adopted 39 files and rewrote CI and the Makefile, a 3,700-line
   diff nobody asked to review. What the repository lacks against the
   standard goes in the report under Noticed, as a proposal.
   1b. A repository that holds only documents (a PRD, ADRs and an HLD
   written before any code) is a new product, scope full: the repo
   stage scaffolds the stack into it with `brg-scaffold`, which keeps
   every existing file, and the repo plan entry that lives here gets
   `"path": "."`.
   1c. The branch stage comes next, before any document: `start-task`
   names it (`feature/NOTASK-<n>-<Name>` without a tracker), so every
   later stage commits on the task branch and the trunk is never
   written.
2. Loop until `next` says every stage is done or a stage is blocked:
   1. `next` names the stage, its skill and its gate.
   2. Run the stage's skill in auto mode (below).
   3. `done <stage>`. On "gate not met", fix what it names and run
      `done` again; when the same stage cannot be fixed, `fail <stage>
      "<why>"`, which allows three attempts before the stage is blocked.
3. Auto mode, for every stage: wherever a skill says to ask the user, to
   stop and wait, or to confirm, take the option the skill recommends
   and go on. Then:
   - record the choice with `decision <key> "<choice>" "<alternatives>"
     "<why>" --adr <path>`, one row per choice, in the words a reviewer
     needs;
   - any ADR or decision record the stage writes has status Proposed and
     names no decider; `done decide` fails on an Accepted one;
   - a key the repository or the statement already settles is cited,
     not decided again (tech-decision step 2); when nothing is open, record
     `decision none-open - - "<why>"`.
   - in an existing repository, its written conventions and then its
     code are the precedent: a new command's output, exit statuses and
     error handling follow them unless the statement says otherwise
     (where the two disagree, see below), and existing
     behaviour the statement does not mention (other commands' exit
     codes, what `make check` does, CI) is not changed. A better
     convention is a proposal under Noticed, not a change in this MR.
4. The product profile, at the end of the decide stage: `profile --ui
   yes|no --data yes|no --api yes|no --deploy yes|no [--llm yes|no]
   [--ui-stack <stack>] [--scope lean|full] --why "<reason>"`. The ui stack is React with shadcn/ui and Tailwind
   (`react-shadcn`) unless the statement or the repository names another;
   only then pass `--ui-stack` (flutter, react-native, compose, swiftui,
   html) and record why.
   It decides which stages apply: ux and design_review need ui, the data
   model data, the API contract api, the deployment architecture deploy,
   and llm (the product calls a language model at run time) adds
   genai-design to design and llm-guardrails and llm-eval to
   test_automation.
   Answer from the statement and the stories, not from convenience: the
   dod gate refuses a profile the code contradicts (a UI package with
   ui=no, a migrations folder with data=no).
5. Tools go through the repository's make targets: `make setup` once the
   repo stage is done, `make check` for the gate, `make fix` for format.
   Never call a package manager directly (`uv sync`, `pnpm install`): the
   repository asks before those and nobody is there to answer.
6. Before the build, in lean scope: the design note, then test-cases
   (the risk register and the case table only). In full scope:
   architecture-diagram writes the C4 file; design
   runs high-level-design, then data-model, openapi-spec and
   deployment-architecture as the profile names, then threat-model (it
   needs the entry points and stored fields those wrote) and genai-design
   when the profile says llm;
   repos runs new-repo once for each entry of
   docs/architecture/repo-plan.json, in `<parent>/<Name>` beside this
   repository (an entry named like this repository is this repository
   and is not created again); for a
   UI, ux runs ux-flows, then design-directions --unattended (three
   directions as token themes over the real screens, scored, the highest
   chosen into approved.json; any reference look the statement names is
   the brief), design-system from the chosen direction (the shadcn
   variables, one UI face and a mono), motion-design (docs/design/motion.md)
   and screen-design (on react-shadcn every screen a *.screen.tsx in
   the design gallery, composed from src/components/ui, every state from
   fixtures, responsive at 375, 768 and 1440); the build wires those same
   components to data. Then lld runs low-level-design once for each
   component the HLD's "What gets built" table says this run builds,
   after the screens, because a front-end component's design names them
   and a server component's design needs the API and data model.
   test-cases writes the TC-nnnn table. The ux
   and test_cases gates run the skills' own checkers (flows_check,
   contrast, gallery_check or states_check, design-lint, cases_check).
   The repos gate reads each sibling: a git repository whose `make check`
   records a pass and has passed. Headless, the sandbox lets the run
   write only inside this repository: run `brg-autopilot repos-request`
   and end your turn; the launcher scaffolds the missing entries with
   `brg-scaffold --check` outside it and resumes the session with what it
   made. The siblings stay as scaffolded: the build, the tests and the
   MR are this repository's.
7. Build is test first, story by story, in the order of the backlog:
   a failing test named for the story, the code, `make check`, a commit
   per story with the task id. Where the Makefile records a build pass
   (the Next.js and React templates do), `make build` runs too before the
   stage is done: a page that cannot prerender passes every check and
   fails only the build. The edit hook's lint findings are fixed
   when they arrive; the Stop hook's `make check` demand is met, not
   argued with. No test asserts on wall-clock time: it passes on the
   laptop and flakes in CI. Before the first line of code, read the
   traps below and put the ones that apply into the tests.
   A build split across parallel subagents gives each a disjoint set of
   files and a migration timestamp range, forbids git commands that
   change state, and has the supervisor commit. Each agent's checks stay
   scoped to its own files: with one shared local database, a reset by
   one agent fails another's `make test-db` mid-run, so an agent reruns
   only its own pgTAP file (`supabase test db <file>`) and the
   supervisor runs the full `make test-db` once the batch lands. Other
   agents' type and lint errors are listed, not fixed.
8. After the build: test-automation names a test after every case
   that is not manual-only or retired (its TC id in the test name); with
   llm in the profile, llm-guardrails writes `guardrails/policy.yaml` and
   wires it at the call sites, and llm-eval writes `docs/genai/evals.md`
   (an eval that needs a provider key the run lacks is written and marked
   not run, never reported as passed); for a
   UI, design-critique scores the design gallery of the running app
   (`make dev`) across every screen and state, fixes the top findings
   and re-scores until the bar holds: overall 8.0, no category below 7,
   every screenshot present. The design_review gate reads the report;
   a design under the bar is not done, however many stages passed.
9. Review is `branch-review`; fix every Critical and High it confirms, then
   `make check` again. `definition-of-done` walks the definition of done, including
   item 13: start what the repository ships and drive its main flow,
   sign-in first, against the real backend. A bug the smoke run finds is
   fixed test first like any other, then the smoke runs again; the dod
   gate refuses a smoke file older than the last commit. Headless
   (`BRG_AUTOPILOT_HEADLESS=1`, set by `launch`) the sandbox keeps Docker
   and `.env` out of reach: write the checks to
   `.scratch/smoke-plan-<ID>.txt` (`base <url>`, then `METHOD /path
   status` per line) unless the Makefile has a `smoke` target, run
   `brg-autopilot smoke-request --id <ID>` and end your turn. The
   launcher runs the smoke outside the sandbox and resumes the session
   with the file and its verdict; at most 3 rounds.
10. The mr stage: `merge-request` prepares the description; `report` writes
   `docs/autopilot/<run>.md`; commit it, and let that commit be the last
   write (`git status` clean after it: a progress file touched later is
   work the MR does not carry); paste its decisions table into
   the description, with the exact push command (`git push -u origin
   <branch>`) under it; print the same command in the last message. Do
   not run it.
11. Blocked or finished, the last message is the report: stages done,
   the decisions to review, what is not done and why, and the push
   command when the MR is ready.

## Output contract

```
## Autopilot <run>: <statement>
Stages: <n> of 17 done   Blocked: <stage (why)> | none
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

- Reuse the sibling's path, not only its output shape. Read how the
  nearest existing command gets its data (which store function, what it
  normalises, how it handles an old file format or a missing file) and
  call the same function. A new command that reads the raw store
  crashes on the legacy rows its sibling quietly converts.
- Where a conventions document and the code disagree, new code follows
  the document, the old code is left as it is, and the gap goes under
  Noticed with the command that shows it. Silently copying the old
  code's bug and silently fixing it in this MR are both wrong.
- Before dod, run what was built the way the user will, from a shell,
  and read stdout, stderr and the exit status against what the PRD,
  README and conventions promise. Tests the run wrote agree with the
  code by construction; the documents are the independent oracle. A
  promise the program breaks is a bug in one of them, fixed before the
  MR.
- The inputs that break a first version, for the interface in hand:
  - text: case-insensitive means Unicode case folding (`casefold()`,
    not `lower()`: the German sharp s and the Greek final sigma differ);
    a word is letters plus combining marks (categories L and M: `\w`
    and `\pL` alone cut decomposed accents and Indic vowel signs out of
    the word), with NFC normalisation before comparing; bytes that are
    not valid UTF-8 give a clear error or a documented replacement,
    never a stack trace.
  - arguments: missing, empty, repeated, zero, negative, not a number;
    a user's search term is a literal (escaped, or matched without a
    regex), and a word-boundary regex is checked against terms that
    start or end in punctuation, where `\b` does not match beside them.
  - files: missing, unreadable, empty, not the expected format (invalid
    JSON), and an older layout of the same format.
  - errors: the argument library's own output counts; argparse and Go's
    flag print a usage block plus the error, which is not the "one-line
    error" a PRD may have promised. Decide the shape, write it down,
    and test the exact stderr.
- Every example in the README or the design note is run and its output
  pasted from that run, not written from memory.

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
  next stage.
- Unattended from a script: `python3 bin/brg-autopilot launch "<statement>"`
  runs `claude -p` in the directory with the repository's settings, so
  the sandbox and the guard apply.
