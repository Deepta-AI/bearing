# Runtime and feel: speed, sessions, updates, learning, console

Status: draft for review, 2026-10-16. Branch `feat/RuntimeAndFeel`.
Sub-project 1 of 4 in the Bearing improvement programme. The others
(design pipeline, quality phases, GenAI pack) get their own specs.

## Goal

Make Bearing feel fast and self-driving during a session, without
removing any gate. Five points from team feedback, in priority order:

| # | Feedback | Outcome this spec commits to |
|---|---|---|
| 11 | "Bearing is very slow" (waiting on the agent; lag every turn) | No full `make check` mid-session; cheaper review agents; smaller skill bodies; slowness measurable per gate |
| 1 | Session handling is manual | Save and resume happen without anyone typing a command |
| 9 | No update prompt | A new Bearing tag is offered once, with its changelog |
| 10 | Bearing does not learn from use | Opt-in, local learnings that skills read back and that can be proposed upstream |
| 8 | Questions and console feel rough | One question contract, answers remembered, a context-aware menu |

## Evidence (v0.7.0)

- Hook scripts are not the cost. In one scaffolded Go service,
  `gates.log` holds 1,941 gate runs: `check-file` averages 43 ms over
  471 runs, the Bash guard 43 ms over 1,440.
- The Stop gate is. `brg-guard stop-gate` (`plugins/bearing/bin/brg-guard:1612`)
  sends Claude back to run the full `make check` whenever files changed
  since the last pass; in that repository it blocked 9 turns and
  reminded on 6 more. Every block is a full lint and test run plus fixes.
- The formatter in `format-file.sh` runs before `check-file` and is not
  timed, so its cost is invisible.
- `reviewer`, `verifier`, `critic` and `security-auditor` all declare
  `model: opus`; `branch-review` and `vapt-report` run one verifier per
  Critical and High finding.
- 106 skills, 19,133 lines of SKILL.md; ten skills are 250 to 342 lines
  and load whole on every invocation. Impeccable's entry skill is 85
  lines with references read on demand.
- Claude Code ignored 92 `permissions.allow` entries in an untrusted
  workspace during an autopilot run, so every command waited on a prompt.
- Sessions: `start-task` asks for id, type and name; `session-handoff`
  runs only when invoked; SessionStart prints 20 lines of the state file.
- Updates: only the manual `upgrade-tools`. Learning: nothing exists.
- Questions: only `prd` uses AskUserQuestion; the other skills ask in prose.

## Non-goals

- No gate is removed or made optional. `definition-of-done` and the
  pre-push gate still run the full `make check`.
- No telemetry leaves the machine. Nothing is sent to any service.
- No `fast`/`strict` profile switch (rejected in review: it weakens gates
  mid-session).
- No rewrite of hook scripts in a compiled language (they cost 43 ms).
- Design, testing, review and GenAI flow changes belong to sub-projects 2 to 4.

## Design

### A. Speed (point 11)

**A1. Scoped Stop gate.** Add a `check-changed` target to all 13 stack
Makefile templates. It runs format check, lint and the tests of the
packages that contain files changed since `$(STATE)/.check-passed`
(tracked and untracked, from `git status --porcelain`), and prints the
count of files and packages it checked; zero changed files prints
`check-changed: 0 files, nothing to check` and exits 0 (the Stop gate
only calls it when its own count is above zero). It does not write
`.check-passed`; it writes `.check-changed-passed`. `stop-gate` asks for
`make check-changed` when the Makefile has that target, else falls back
to today's `make check` message, and treats a file older than
`.check-changed-passed` as checked. Per stack, "package" means: Go
package dir, Python test module mapped by path, the nearest
`package.json` workspace for Node/React/Next.js/React Native, the Gradle
module for Android, the Swift package or Xcode scheme for iOS, the
Flutter package, the Terraform root for infra, the dbt model for
data-pipeline. A stack that cannot scope runs its full test target and
says `check-changed: <stack> cannot scope, ran all tests`.

`definition-of-done`, `make gate` and the pre-push hook keep requiring
`.check-passed` from the full `make check`.

**A2. Time every hook step.** `format-file.sh` logs its own `format`
line to `gates.log` with duration, like `check-file`. `stop-gate` logs
the duration Claude spent between the block and the next Stop. A new
`doctor --timing` section reads `gates.log` and prints, per gate: runs,
median and p90 ms, blocks. This is how we prove A1 to A4 worked.

**A3. Review agents by severity.** `verifier`, `critic` and
`security-auditor` default to `model: sonnet`. Skills that dispatch them
pass `model: opus` only for a Critical finding, for `critic` in graded
`high-level-design` mode, and for `vapt-report`. `reviewer` stays Opus
(one call per branch). Independent verifier calls are dispatched in one
message so they run in parallel; `branch-review` and `vapt-report` are
checked for sequential dispatch and fixed.

**A4. Short skill bodies.** The ten largest SKILL.md files
(test-automation, screen-design, high-level-design, flutter, autopilot,
ux-flows, health-checks, data-model, backlog, design-system) move
detail into `reference/*.md` read on demand, keeping in SKILL.md the
inputs, steps, output contract and gotchas. Target: each under 150
lines. A new `lint-skill-size` target fails any SKILL.md over 200 lines
and prints the count checked and the largest file. Existing skills over
200 lines are fixed in this branch, not grandfathered.

**A5. Trust check.** `doctor` reports when the current workspace is not
trusted in `~/.claude.json` and how many allow entries are being ignored,
with the one-line fix. Autopilot's preflight runs the same check and
stops with that message instead of running into permission waits.

### B. Sessions (point 1)

**B1. Timeline from a hook, not a preamble.** A `PreToolUse` hook with
matcher `Skill` runs `brg-guard timeline`, which appends
`{ts, session, branch, skill, args_digest}` to
`.bearing/state/timeline.jsonl` (gitignored, rotated at 512 KB). The
previous open entry on the same session is closed with `ended` at the
next Skill start or at Stop. No skill body changes, and no extra model
turn per skill. (Changed from the chat design's per-skill preamble,
which cost one tool call per invocation and an edit to 106 skills.)
Verification task 0 in the plan confirms the hook fires with
`tool_input.skill`; if it does not, fall back to a preamble limited to
skills listed in `docs/flows.json`.

**B2. Automatic checkpoint.** The Stop and PreCompact hooks write
`.bearing/state/<branch>.checkpoint.md`: task id, branch, base, ahead and
behind, uncommitted file count, last three skills from the timeline, the
next flow step (B4), and the last `Next:` line from the state file. Pure
bash and git, no model call, logged with duration. The existing
narrative state file stays owned by `start-task` and `session-handoff`.

**B3. Tracked progress on handoff only.** `docs/progress/<ID>.md` is
written by `session-handoff` (as today) and by a new `SessionEnd` hook
that calls `progress.py write` with the checkpoint data when the branch
has a task id. It is never committed by Bearing; the engineer commits it.

**B4. Automatic resume.** On `startup` and `resume`, `brg-guard session`
derives the task id from the branch name (`<type>/<ID>-<Name>` or the
repository's convention), prints the checkpoint, and computes the next
step by matching the timeline against the flow in `docs/flows.json` the
task follows (bugfix, feature, greenfield; chosen from the branch type
and the timeline). It ends with one line the model turns into a question:
`Resume <ID>: last ran <skill>. Next: <skill>. Continue?` Output stays
under 40 lines.

**B5. `start-task` stops re-asking.** When the current branch already
encodes id and type, `start-task` reports existing work instead of asking.
Asking for an id remains only when the request and branch give none.

### C. Updates (point 9)

At `startup`, `brg-guard session` runs `brg-update-check` in the
background with a 3 s budget. It reads the installed version from the
plugin's `plugin.json`, runs `git ls-remote --tags` on the marketplace
URL from `~/.claude/plugins/known_marketplaces.json`, and caches the
newest `v*` tag in `~/.config/bearing/update-check` for 24 hours. When
the cached tag is newer and not snoozed, the session output carries
`BEARING_UPDATE: 0.7.0 -> 0.8.0` plus up to 8 CHANGELOG lines fetched at
check time. The console contract (E) turns that into one question:
**Upgrade now** (runs `upgrade-tools`), **Remind me tomorrow**, **Skip
this version**; the answer is written to `~/.config/bearing/bearing.env`
(`BEARING_UPDATE_SNOOZE_UNTIL`, `BEARING_UPDATE_SKIP`). Offline, timeout
or a parse failure writes `update status unknown` to the log and prints
nothing to the session. `BEARING_UPDATE_CHECK=off` disables it.

### D. Learning (point 10)

**D1. Consent once.** The first session after upgrade carries
`BEARING_LEARNING: ask`; the console contract asks once: **Yes, learn
locally**, **No**. The answer is stored as `BEARING_LEARNING=on|off` in
`bearing.env`. Unanswered is not stored and is asked next session.

**D2. What is logged** (only when on), to
`~/.config/bearing/learnings.jsonl`: gate blocks and their fixes
(gate, rule, file extension), skills abandoned or rerun within ten
minutes, questions a user answered differently from the recommended
option, and explicit `learn add "<text>"` entries. Each entry is
`{ts, kind, skill, key, insight, count}` with paths reduced to
extension and repository names hashed. No source code, prompts or file
contents are stored.

**D3. Read back.** `brg-guard session` prints up to five learnings for
skills in the next flow step, ranked by count and recency.

**D4. Propose upstream.** A new `learn` skill: `learn` lists,
`learn add` records, `learn propose` groups entries seen three or more
times into a drafted issue body for `Deepta-AI/bearing` in
`.scratch/learn-proposal.md`, after a redaction pass that fails on any
path, hostname, email or identifier not on an allowlist, and prints the
`gh issue create` command for the engineer to run. Bearing never files it.

### E. Console contract (point 8)

**E1. `console.md`.** A shared reference at
`plugins/bearing/reference/console.md` that skills cite. Rules taken from
impeccable's practice: infer from the repository first and confirm
inferences; use AskUserQuestion, at most three questions a round, two to
four options, recommended option first and labelled; state each
trade-off in plain words; record answers and never re-ask; a
recommendation is never stored as an answer; prose fallback only when the
tool is unavailable, said so in one line. Output: lead with the result,
then the AGENTS.md report shape; no tours.

**E2. Remembered answers.** Project answers go in `.bearing/config.json`
(tracked, so the team shares them); per-person answers in
`bearing.env`. A helper `brg-guard config get|set` reads and writes
both. Skills that today ask stack, tracker, design direction or build
path check config first.

**E3. Context-aware menu.** The `workflow` skill with no argument reads
the checkpoint and timeline and leads with the two or three best next
skills, each with a one-line reason, then the full stage map. It never
runs anything without an answer.

**E4. Gate.** `lint-questions` fails a skill whose body tells the model
to ask the user in prose (`ask the user`, `ask once`, `ask:`) without
`AskUserQuestion` in its `allowed-tools` and a citation of `console.md`,
and prints the number of skills checked and found. The skills it flags
are converted in this branch.

## Error handling

Every new hook step is non-fatal: on any failure it logs
`<gate> not-run <reason>` to `gates.log` and exits 0, except the existing
Stop gate block, which keeps its one-block-then-remind rule. Every new
hook keeps a timeout of 5 s or less except Stop (15 s). Files under
`.bearing/state` and `~/.config/bearing` are written atomically
(temp file, then `mv`).

## Testing and gates

- `tests/` gets cases for: `check-changed` in every stack template
  (scaffold, touch one file, assert the package count and that an
  unrelated package's failing test is not run); `stop-gate` choosing
  `check-changed`; timeline open and close; checkpoint content; next-step
  computation per flow; update check with a fake remote (newer, same,
  offline, snoozed, skipped); learning consent states and redaction
  (a planted path, email and hostname must fail `learn propose`).
- New lints: `lint-skill-size`, `lint-questions`. Both fail on zero
  skills found and print counts.
- Speed acceptance, measured with `doctor --timing` on a scaffolded Go
  and a Next.js repository running the same scripted bugfix before and
  after: no full `make check` before `definition-of-done`; Stop-gate
  check median at least 50% lower than the full `make check` on that
  repository; no hook step median above 200 ms except `check-changed`.
- `make check` on this repository passes, with counts in the MR.

## Rollout

Ships as 0.8.0. CHANGELOG lists each behaviour change, and the update
prompt (C) will show it to teams already on 0.7.0 once 0.8.0 is
tagged. Templates gain `check-changed`; existing repositories get it
through `onboard-repo` or by copying the target, and until then the Stop
gate falls back to today's behaviour.

## Risks

- `PreToolUse` on `Skill` may not carry the skill name in every Claude
  Code version. Mitigated by plan task 0 and the preamble fallback.
- Package scoping can miss a cross-package break. Accepted: the full
  `make check` still runs at `definition-of-done` and pre-push.
- Sonnet verifiers may refute real findings more often. Mitigated by
  keeping Opus on Critical; compare refute rates on the `evals/` review
  cases before and after.
- Splitting skills can drop rules. Each split is diffed rule by rule and
  `evals/` trigger and behaviour cases must pass unchanged.
