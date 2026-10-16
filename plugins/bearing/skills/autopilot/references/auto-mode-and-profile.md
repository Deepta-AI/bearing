# autopilot: auto mode, the product profile and tools

Read at steps 3 to 5: taking the recommended option, recording decisions, the profile flags, and tools through make.

3. Auto mode, for every stage: wherever a skill says to ask a question, to
stop and wait, or to confirm, take the option the skill recommends
and go on. Then:
- record the choice with `decision <key> "<choice>" "<alternatives>" "<why>" --adr <path>`,
  one row per choice, in the words a reviewer
  needs;
- any ADR or decision record the stage writes has status Proposed and
  names no decider; `done decide` fails on an Accepted one;
- a key the repository or the statement already settles is cited,
  not decided again (tech-decision step 2); when nothing is open, record
  `decision none-open - - "<why>"`.
- in an existing repository, its written conventions and then its
  code are the precedent: a new command's output, exit statuses and
  error handling follow them unless the statement says otherwise
  (where the two disagree, see references/reviewer-checks.md), and existing
  behaviour the statement does not mention (other commands' exit
  codes, what `make check` does, CI) is not changed. A better
  convention is a proposal under Noticed, not a change in this MR.
4. The product profile, at the end of the decide stage: `profile --ui yes|no --data yes|no --api yes|no --deploy yes|no [--llm yes|no] [--ui-stack <stack>] [--scope lean|full] --why "<reason>"`.
The ui stack is React with shadcn/ui and Tailwind
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
