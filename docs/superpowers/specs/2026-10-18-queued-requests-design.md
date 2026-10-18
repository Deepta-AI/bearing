# Queued requests: opt-in push, a site flow, multi-repo tasks

Status: draft for review, 2026-10-18. Branch `feat/QueuedRequests`, cut
from `main` at `e6d407d` (v0.8.0). Sub-project 5 of the Bearing
improvement programme. Sub-projects 2 (design pipeline), 3 (quality
phases) and 4 (GenAI pack, the `bearing-genai` plugin) merge first; this
branch is rebased on top of them before its plan runs.

The user skipped the brainstorming questions. Every choice below that
is not quoted from the three requests is marked **author's call**.
Repository facts are cited as `path:line` at `e6d407d`.

## Intent

Three requests the tech lead queued, in the order given:

| # | Request (as queued) | Outcome this spec commits to |
|---|---|---|
| 1 | Opt-in auto push from bearing.env; default off; the current feature branch only, never main, master, release branches or tags, never force, never merge, after the gate passes | One personal opt-in key; one executor (`brg-push`) that the Stop hook runs outside the sandbox; the raw `git push` stays blocked everywhere; every "never pushes" claim names the exception |
| 2 | A light workflow for marketing landing pages and websites: no PRD, HLD, LLD or API contract; keeps screen design, accessibility, performance and a review | A sixth flow, `site`, in `docs/flows.json`, eleven steps on its main line, chosen per repository |
| 3 | Simpler, explicit multi-repo and microservices handling: start, track, finish; state files, branch names, one MR per repo, merge order; smallest change to five skills | A "task set": one task id, one branch name in every repository, a `## Repos` section in each repository's progress file, one MR per repository, a declared merge order, and one shared reference the five skills cite |

## Constraints

- No em dashes in any file (`make lint-prose`, `Makefile:147-150`).
- Every gate fails on empty input and prints the count it checked
  (user standing rule; the house pattern is `lint-plugin-size`,
  `bin/lint-plugin-size.py:22-23,51`).
- A skill that asks uses AskUserQuestion in `allowed-tools` and cites
  `${CLAUDE_PLUGIN_ROOT}/references/console.md`
  (`plugins/bearing/references/console.md:14-17`; enforced by
  `lint-questions`, `Makefile:85-96`).
- Shell is bash 3.2 portable: no `sed -i`, `grep -P`, `readlink -f`,
  `date -d`, no `perl` (`make lint-portable`); Python is stdlib only.
- Every SKILL.md stays at 200 lines or fewer (`lint-skill-size`,
  `Makefile:68-83`); detail goes to `references/`.
- Every command a skill body runs is granted in its `allowed-tools`
  (`lint-tools`, `bin/lint-skill-tools.py:1-30`); `Bash(git -C` grants
  are refused outright (`Makefile:49`).
- Files under `plugins/bearing` stay few: the plugin is at 508 files today
  and about 451 after sub-project 4; the limit is under 512
  (`bin/lint-plugin-size.py:14`). This spec adds **2** files there:
  `bin/brg-push` and `references/task-set.md`.
- Commits are Conventional, with no attribution trailer of any kind.
- Bearing itself never pushes, merges or tags this branch; the engineer does.

## Repository facts the design rests on

- There is no per-repository `bearing.env`. The file is personal:
  "Mode 600. Never inside a repository."
  (`plugins/bearing/templates/user/bearing.env:1`). Project answers live
  in the tracked `.bearing/config.json`; personal ones in `bearing.env`
  (`plugins/bearing/bin/brg-config:2-4`).
- Four layers stop a push today, and the devguide says so: AGENTS.md rule 2
  (`plugins/bearing/templates/repo/AGENTS.md:16`), the settings deny
  `Bash(git push:*)` (`plugins/bearing/templates/repo/.claude/settings.json:160`),
  the guard's verb row `git|push` (`plugins/bearing/bin/brg-guard:69`, message
  at `:253`), and the pre-push hook refusing any agent environment
  (`plugins/bearing/templates/repo/.githooks/pre-push:60-82`)
  (`devguide/src/pages/Architecture.tsx:49-53,207`).
- A fifth layer exists: the sandbox. Its network allowlist has no git
  host, so a push from any sandboxed Bash call fails at the network, and
  it denies reads and writes of `~/.config/bearing`
  (`settings.json:361,410-424`). Anything that pushes must therefore run
  outside the sandbox. Hooks do; Bash calls do not.
- The guard reads `bash <file> args` as `<file> args` and matches the
  basename (`brg-guard:1148-1182`), so a verb row for a kit script blocks
  it however it is called.
- The Stop gate already knows whether `make check` passed after the last
  change and logs `stop-gate passed` (`brg-guard:1645-1672`).
- Autopilot's `mr` gate fails when the branch has an upstream that moved
  during the run (`plugins/bearing/bin/brg-autopilot:796-815`); its report
  says "Nothing was pushed, merged or deployed." (`brg-autopilot:959`).
- Flows are data: `docs/flows.json` (four flows today, five after
  sub-project 4), validated by `bin/gen-guide.py:1273-1340`, rendered by
  the site from `site/src/data/handbook.json`, and compiled into
  `plugins/bearing/bin/flow-steps.tsv` for `brg-session next-step`, which
  picks the flow from the branch type only
  (`plugins/bearing/bin/brg-session:103-110`).
- Multi-repo today: `high-level-design` writes
  `docs/architecture/repo-plan.json` with one entry per repository and a
  `git_path` of `<group>/<Client|Server|Infrastructure>/<name>`
  (`plugins/bearing/skills/high-level-design/references/design-set.md:9-15`,
  template `.../templates/repo-plan.json`); autopilot scaffolds siblings
  beside the run's repository but builds and opens the MR in that one
  repository only (`plugins/bearing/skills/autopilot/references/design-stages.md:31-37`).
  The state file is per branch, per repository and ignored
  (`plugins/bearing/bin/brg-state-path:1-17`); the progress file
  `docs/progress/<ID>.md` is per repository and committed
  (`plugins/bearing/skills/session-handoff/scripts/progress.py:1-34`).

## Design

### A. Opt-in push (request 1)

**A1. The key.** `BEARING_AUTO_PUSH` in the personal `bearing.env`. The
request says "the repository's bearing.env"; no such file exists, so
**author's call**: the opt-in is personal and names repositories. Value:
a space- or comma-separated list of repository paths as the origin URL
spells them, host and `.git` removed (`Shop/Server/ShopApi`), the same
shape as `git_path` in the repo plan. Empty, unset or `off` is off. No
wildcard (anti-goal G1). The key is read from the file only, never from
the environment, unlike the other keys
(`plugins/bearing/templates/user/bearing.env:6-7`), because an
environment variable is something an agent can set; `BEARING_ENV` still
names another file for tests.

Why personal and not `.bearing/config.json`: the standing rule "I push,
merge, tag and deploy" is the engineer's, and a tracked key would let a
cloned repository turn pushing on for everyone who opens it. A team that
wants it documents the line to add in its CONTRIBUTING.md (open
question Q1 offers the two-key variant).

**A2. Nobody but the engineer writes it.** `brg-config set` refuses any
key that maps to `BEARING_AUTO_PUSH` (`auto-push`, `auto_push`,
`AUTO.PUSH`; the mapping is at `brg-config:9`) with exit 2 and
"set BEARING_AUTO_PUSH by hand in bearing.env". The settings template
adds `Edit(~/.config/bearing/**)` to `permissions.deny`, so Edit and
Write cannot reach the file even under autopilot's `--allowedTools Write`
(`brg-autopilot:1252`); the sandbox already denies Bash writes there
(`settings.json:420-422`). As a last line, `brg-push run` refuses when
`bearing.env` is newer than the session's start mark
(`.bearing/state/.session-<id>`, written at `brg-guard:1570-1574`): an
opt-in must predate the session that uses it.

**A3. One executor, `plugins/bearing/bin/brg-push`.** Bash 3.2, about
200 lines, the only new script. Subcommands:

```
brg-push check            the conditions below, one line each, then
                          "push-check: N conditions, M met"; exit 0 all met,
                          1 any unmet, 2 usage or not a git repository
brg-push request          check; when it exits 0, write
                          .bearing/state/push-request (branch, HEAD sha, time)
brg-push run --id <sid>   Stop hook only: check again plus the request and
                          opt-in age conditions; then push in the background
brg-push status           the last result line, or "push: none"
brg-push optin-record     SessionStart only: write .bearing/state/.push-optin
                          (on|off) for this repository from bearing.env
```

Conditions, each printed as `ok <name>: <detail>` or `no <name>: <detail>`:

1. `opt-in`: `check` reads `.bearing/state/.push-optin` (written at
   session start, outside the sandbox, because the sandbox hides
   `bearing.env` from Bash); `run` reads `bearing.env` itself.
2. `origin`: a remote named `origin` exists; its path is the one listed.
3. `branch`: on a branch (not detached) matching
   `^(feature|bugfix|hotfix|chore|docs)/[A-Z][A-Z0-9]*(-[0-9]+)+-[A-Za-z0-9]+$`
   (`plugins/bearing/skills/merge-request/SKILL.md:56`).
4. `not-protected`: not `main`, `master`, `develop`, not `release/*`,
   and not in `PROTECTED_BRANCHES` of `.githooks/lib.sh` when present
   (`templates/repo/.githooks/lib.sh:12`). **Author's call**: `hotfix/*`
   is allowed, because this is a branch push, not a merge (Q2).
5. `clean`: `git status --porcelain --untracked-files=no` is empty.
6. `ahead`: at least one commit on the branch not on the base
   (`origin/develop`, else `origin/main`, else `origin/master`).
7. `gate`: `.bearing/state/.check-passed` exists and no file in the branch
   diff (`git diff --name-only <base>...HEAD`) or the working tree is
   newer than it; the line prints how many files it compared. Zero files
   compared is `no gate: 0 files on the branch`.
8. `fast-forward`: `origin/<branch>` absent, or an ancestor of HEAD
   (`check` uses the local ref; `run` fetches first). There is no force
   option at all.
9. `pre-push`: `core.hooksPath` unset, or its `lib.sh` defines
   `auto_push_allowed` (A5); otherwise the hook would refuse the push and
   `check` says which file to update.
10. `request` (`run` only): `.bearing/state/push-request` names this
    branch and HEAD's sha.
11. `opt-in-age` (`run` only): `bearing.env` older than the session mark.

The push itself, the only form `brg-push` ever runs:
`GIT_TERMINAL_PROMPT=0 git push --no-follow-tags --set-upstream origin HEAD:refs/heads/<branch>`.
No `--force`, `--force-with-lease`, `--tags`, `--all`, `--mirror`,
`--delete`, no second refspec. `run` detaches (`nohup ... &`) so the
Stop hook returns inside its 15 s timeout
(`plugins/bearing/hooks/hooks.json`), writes `.bearing/state/push.log`
and one line to `.bearing/state/push-result`
(`pushed <branch> <sha> to origin <time>` or `push failed: <reason>`),
and logs gate `push` with outcome `pushed|refused|failed` through the
same `gates.log` format (`brg-guard:262-297`). Every refusal deletes the
request, so a stale request never fires later.

**A4. Where the guard checks it.** Three places in `brg-guard`, no new
hook script:

- `command`: the verb row `git|push` (`brg-guard:69`) and its message
  (`:253`) are unchanged; a raw push stays blocked in every repository,
  opted in or not. One new row, `brg-push|run|brg-push run (the Stop hook
  runs it)`, so the agent can check and request but never execute.
- `stop-gate`: on the `passed` branch (`brg-guard:1672`), when
  `.bearing/state/push-request` exists and `brg-push` sits beside the
  guard, run `brg-push run --id <sid>`; its output is one line. A
  blocked or reminded stop never pushes, which is how "after the gate
  passes" is enforced.
- `session` and `task-id`: `session` calls `brg-push optin-record` on
  startup and resume, and both print an unseen `push-result` once
  (`bearing push: pushed feature/X abc1234 to origin`), then mark it
  seen. That is how the model, and so the engineer, learns the outcome.

`brg-harness` does not vendor `brg-push` (`brg-harness:160-164` vendors
the session scripts only), and `stop-gate` skips the push when the file
is absent, so other harnesses keep today's behaviour (anti-goal G4).

**A5. The pre-push hook.** Both copies
(`plugins/bearing/templates/repo/.githooks/` and
`plugins/bearing/skills/git-hooks/templates/.githooks/`, kept identical
by `Makefile:59`) gain `auto_push_allowed` in `lib.sh`: it reads
`${BEARING_ENV:-${XDG_CONFIG_HOME:-$HOME/.config}/bearing/bearing.env}`
directly and returns 0 when `BEARING_AUTO_PUSH` lists this repository.
In `pre-push`, where an agent environment is detected
(`pre-push:62-70`), the push is allowed only when `auto_push_allowed`,
every ref is a branch (a tag ref is refused, not skipped as at
`pre-push:34`), no ref is protected or `release/*`, and every ref is a
fast-forward (`git merge-base --is-ancestor <remote sha> <local sha>`
when the remote sha is not zero). It notes
`agent push allowed by BEARING_AUTO_PUSH: <n> branch ref(s)` and then
runs the full `GATE_CMD` exactly as today (`pre-push:84-97`). A
repository with older hooks refuses the agent push, `brg-push` records
"pre-push refused", and condition 9 named it in advance.

**A6. How merge-request uses it.** Step 8
(`merge-request/SKILL.md:93-98`) gains: run `brg-push check`; when it
exits 0, run `brg-push request` and print
`Push: requested; the Stop hook pushes <branch> to origin when this turn ends and the gate holds (brg-push status shows the result)`;
otherwise print the unmet conditions in one line and the push command as
today. The MR or PR itself is never created (forge writes stay blocked,
anti-goal G2). The output contract's `Push:` line
(`merge-request/SKILL.md:123`) becomes
`Push: requested (opt-in) | yours: git push -u origin <branch>`. The
gotcha at `merge-request/SKILL.md:128` keeps "never run `git push`" and
adds that `brg-push request` is the only push path. Grants:
`Bash(bash *bin/brg-push check*)`, `Bash(bash *bin/brg-push request*)`,
`Bash(bash *bin/brg-push status*)`.

**A7. How autopilot uses it.** Step 10 (`autopilot/SKILL.md:74-78`) and
`references/review-smoke-and-mr.md:28`: after the report commit (the
last write), run `brg-push check`, then `brg-push request` when it
passes; the run's final Stop pushes. The output contract line
`Push (yours): ...` (`autopilot/SKILL.md:93`) becomes
`Push: requested (opt-in) | yours: git push -u origin <branch>`.
`brg-autopilot`:
- `g_mr` (`brg-autopilot:796-815`) also passes when the upstream's sha
  equals HEAD and `.bearing/state/push-result` records that sha as
  pushed by `brg-push`; any other upstream movement still fails with
  "the run must not push".
- the `mr` stage text (`:112`) reads "nothing pushed except by brg-push
  under the opt-in".
- the report sentence (`:959`) reads "Nothing was merged or deployed;
  the push is <requested under BEARING_AUTO_PUSH | the engineer's>."
The launcher (`brg-autopilot launch`) does not push; the child
session's Stop hook does (one executor).

**A8. Every "never pushes" claim and its change.** Raw `git push` by the
agent stays forbidden everywhere; each claim gains the one exception, or
stays because it describes that raw push.

| Where | Today | Change |
|---|---|---|
| `README.md:6` | "the agent never pushes" | "the agent never pushes except, where you opt a repository in, its feature branch after the gate" |
| `README.md:85` (Stop row) | stop gate only | adds "then, when merge-request requested it and the repository is opted in, `brg-push run`" |
| `README.md:120` | "The engineer runs these" | adds one sentence: the opt-in exception and `BEARING_AUTO_PUSH` |
| `README.md:237-243` Configuration | keys | names `BEARING_AUTO_PUSH` |
| `docs/INSTALL.md:101-115` key table | 13 keys | adds the `BEARING_AUTO_PUSH` row, default empty (off) |
| `plugins/bearing/templates/user/bearing.env` | no key | a commented `# BEARING_AUTO_PUSH=` block with the rules |
| `CONTRIBUTING.md:120` | "A skill never pushes" | "A skill never pushes, except merge-request and autopilot through `brg-push request` under the opt-in" |
| `plugins/bearing/templates/repo/AGENTS.md:16` rule 2 | never push | adds "except a `brg-push request` where the engineer opted this repository in" (budget 3,600 bytes, file is 2,864: `Makefile:157`) |
| `plugins/bearing/templates/repo/.claude/settings.json:10,16` `_readme` | "push ... stay blocked" | names the hook-run exception; deny list unchanged plus `Edit(~/.config/bearing/**)` |
| `plugins/bearing/hooks/hooks.json:2` | "the agent does not" | adds "except an opted-in feature branch push from the Stop hook" |
| `plugins/bearing/bin/brg-guard:64` comment | engineer pushes | adds the `brg-push` exception; the deny message at `:253` is unchanged (it answers a raw push, pinned by `tests/unit/guard_deny_table.sh:474`) |
| `.githooks/pre-push:60,68,70` (both copies) | agents refused | A5 |
| `plugins/bearing/skills/merge-request/SKILL.md:3,10,93-98,123,128` | "never pushes" | A6; the description ends "pushes only where opted in" within 220 chars |
| `plugins/bearing/skills/autopilot/SKILL.md:3,13-15,74-81,93` | "never pushes" | A7, same description pattern |
| `plugins/bearing/skills/autopilot/references/review-smoke-and-mr.md:28` | push command | A7 |
| `plugins/bearing/skills/start-task/SKILL.md:100,161` | "which the engineer runs" | "which the engineer runs, or merge-request requests under the opt-in" |
| `plugins/bearing/bin/brg-autopilot:9,112,959` | nothing pushed | A7 |
| `bin/gen-guide.py:800` | "the engineer pushes" | "the engineer pushes, or the Stop hook where the repository opts in" |
| `docs/flows.json:509,893` (`mr` steps) | "never pushes", "the engineer pushes" | the same qualifier |
| `docs/WORKFLOW.md:232,243` (hand-written) | never pushes | qualifier; lines 157 and 187 are generated and follow `gen-guide.py` |
| `devguide/src/pages/Architecture.tsx:49-53,207` | four walls | each wall's text names how the opt-in passes it (only the Stop hook's `brg-push` passes the guard and the deny; the pre-push hook checks the opt-in itself) |
| `devguide/src/pages/Autopilot.tsx:165`, `Start.tsx:133`, `Home.tsx:28` | never pushes | qualifier |
| `site/src/pages/Guides.tsx:167,443` | never pushes | qualifier |
| `plugins/bearing/bin/brg-harness:360,381,502,584` | never push (other harnesses) | unchanged: no auto push off Claude Code (G4) |
| `devguide/src/data/recordings.json`, `devguide/src/components/GuardAnatomy.tsx:26,40`, `devguide/src/pages/Session.tsx:108` | the raw-push deny message | unchanged: still true |
| `devguide/src/pages/Change.tsx:278` | the kit's own repository | unchanged: this repository has no opt-in |
| `evals/*` fixtures and expectations | nothing pushed | unchanged: evals run without the opt-in, so they stay true |
| `docs/SKILLS.md`, `site/src/data/handbook.json`, `devguide/src/data/internals.json` | generated | regenerated by `make docs` |

### B. The site flow (request 2)

A sixth entry in `docs/flows.json` (fifth before sub-project 4),
id `site`, title "Marketing site or landing page", tagline "From a goal
and a page brief to a fast, accessible page, reviewed and shipped.",
when "A landing page, a marketing site or a docs-style site: content and
screens, no product backend, no API to design."

Steps (**author's call** for every step and skill; each step carries
`id`, `title`, `skill`, `pack`, `does`, `output`, `why` per
`gen-guide.py:1301-1305`, no ranking words per `:1294,1311-1313`):

```
phase Frame
step s-task      start-task                   bearing
step s-brief     brainstorming                Superpowers   goal, audience, one primary action, sections, copy source
branch "Is there a repository for the site yet?"
  No:  step s-repo new-repo                   bearing       nextjs stack (react-web for a single static page)
  Yes: []
phase Design
step s-direction design-directions            bearing       (sub-project 2 runs one impeccable round inside it)
branch "Does the site follow an existing design system?"
  No:  step s-system design-system            bearing
  Yes: []
step s-screens   screen-design                bearing       every section and state at 375, 768, 1440
phase Build
step s-build     nextjs                       bearing-apps  the screens as components, static by default
branch "Does the page track visitors or collect a form?"
  Yes: step s-events  analytics-events        bearing
       step s-privacy privacy-review          bearing
  No:  []
phase Check
step s-a11y      accessibility                bearing       WCAG 2.2 AA, axe in Playwright
step s-perf      performance                  bearing       Lighthouse before and after
step s-critique  design-critique              bearing
step s-review    branch-review                bearing
phase Ship
step s-dod       definition-of-done           bearing
step s-mr        merge-request                bearing
step s-verify    verify-deploy                bearing       optional: after the engineer deploys, smoke the pages
```

Eleven steps on the main line against about thirty in greenfield; no
`prd`, `backlog`, `high-level-design`, `low-level-design`,
`openapi-spec`, `data-model` or `threat-model` step. The skills named
all exist today (`ls plugins/bearing/skills`, `plugins/bearing-apps/skills/nextjs`)
or are known (`brainstorming` in `docs/known-skills.txt`), so
`gen-guide.py` validates the flow without new skills.

Choosing the flow. `brg-session next-step` picks the flow from the
branch type only (`brg-session:105`). **Author's call**: a repository is
a site repository for its whole life, so the choice is a project answer:
`.bearing/config.json` key `flow` = `site`, written by `start-task` when
the user picks it (new optional `--flow site`, or the request names a
landing page or marketing site and the user confirms with
AskUserQuestion), read by `next-step` before the branch-type rule (a
`bugfix/` branch still follows `bugfix`). The `workflow` skill's stage
table (`workflow/SKILL.md:46-61`) gains a row "Site | the site flow:
`start-task --flow site`".

Site code changes: the colour maps keyed by flow id
(`site/src/pages/Home.tsx:5`, `site/src/lib/nav.ts:7`) gain
`site: "var(--gs)"` (**author's call**: reuse an existing token, as
sub-project 4 does for `genai`). The count of flows in prose
(`docs/flows.json:2` `_about`, `README.md:215,221`, `docs/INSTALL.md:306`,
`bin/gen-guide.py:9`) is updated to the count after rebase.

### C. Multi-repo tasks (request 3)

**C1. The model, a task set.** One task id, N repositories. Each
repository gets the same branch name `<type>/<ID>-<PascalName>`, its own
ignored state file, its own committed `docs/progress/<ID>.md`, its own
gate run, its own MR. Nothing new is shared on disk across repositories;
what links them is the id in the branch name (already what the
UserPromptSubmit hook and `pre-push` read, `brg-guard` `task-id`,
`.githooks/lib.sh:33-38`) and a `## Repos` section that is identical in
every member's progress file.

**Author's call: one session per repository.** The sandbox lets a Bash
call write only inside the working repository (`settings.json:361`), and
`lint-skills` refuses `Bash(git -C` grants (`Makefile:49`), so a skill
cannot create branches or commit in a sibling. Work moves between
repositories by opening a session in each; the set makes that explicit
instead of fighting the sandbox (Q4).

**C2. The `## Repos` section.** Added to
`plugins/bearing/skills/session-handoff/templates/progress.md` as an
optional list, written by `progress.py write --repo "<n>. <Name> (<path>)"`
(repeatable; replaces the list; `none` clears it). `<n>` is the merge
order, `<path>` is relative to the repository (`../ShopApi`). `check`
validates the items (numbers 1..N, unique, names
`[A-Za-z0-9._-]+`). The file still has to stay under 40 lines
(`progress.py:81`); a set of up to eight repositories fits
(**author's call**: more than eight is refused with that reason).

**C3. `progress.py set`.** New read-only subcommand: for each repository
in this repository's `## Repos` section, at its path, with
`git --no-optional-locks` so a read-only sibling never takes the index
lock: present or missing, the branch present, unpushed commits
(`git log <branch> --not --remotes`), uncommitted files, the gate (the
same rule as condition 7 in A3), and the sibling's own progress
`Status`. Each row ends `ready`, `merged` (its Status is merged) or
`not ready: <first reason>`. Last line:
`set: N repos, R ready, M merged, K not ready; merge order A, B, C`.
Exit 1 with zero repositories listed, with no progress file, or with a
missing repository path; 0 otherwise.

**C4. Merge order.** **Author's call**: providers before consumers.
Default from the repo plan's `git_path` group: `Infrastructure`, then
`Server`, then `Client`, then anything else, ties in plan order; without
a plan, the order given to `start-task --repos`. The user confirms it
once with AskUserQuestion. The rule each MR must meet: merged alone, in
that order, it leaves its default branch working (expand, then
contract). A change that cannot merge alone (a breaking API change both
sides need at once) is named under Risk with the two ways out the kit
already has: `api-versioning` or `feature-flags`. Merging stays with the
engineer, one MR at a time, in order.

**C5. The five skills, smallest change each.** The rules live once in
`plugins/bearing/references/task-set.md` (new, about 60 lines, no
commands, so `lint-tools` has nothing to grant from it); each skill
adds a few lines and cites it.

| Skill | Change |
|---|---|
| `start-task` | New optional `--repos <Name,Name,...>` (names from the repo plan, or paths). Steps 1 to 7 run as today in this repository only. Step 7 also writes the `## Repos` section (`progress.py write --repo ...`) after the merge-order question, and the report ends with the exact `start-task <ID> <PascalName> --repos <same list>` line to run in each sibling. Run in a sibling with the same list, it finds the same id and writes the same section. Also gains `--flow site` (B). About 8 lines; 179 today. |
| `session-handoff` | With a `## Repos` section: run `progress.py set` and put its rows in the handoff under a `## Set` heading; Next names the repository the next action is in. About 4 lines; grant already present. |
| `definition-of-done` | One more item after sub-project 3's last: "task set" is `n/a` without a `## Repos` section; `pass` when `progress.py set` shows every repository before this one in the merge order `ready` or `merged`; else `fail` naming them. Grant: `Bash(python3 *skills/session-handoff/scripts/progress.py*)`. About 5 lines. |
| `merge-request` | With a `## Repos` section: the description gains a "Task set" block (each repository, its branch, its order, "merge after <name> | first"); the output contract gains `Set: <k> of <n>; merge after: <name> | first`. About 6 lines; 143 today. |
| `autopilot` | Builds in one repository as today (`design-stages.md:35-37`). When the repo plan holds more than one entry, the mr stage writes the `## Repos` section from the plan in merge order and the report lists the `start-task ... --repos` line for each sibling. About 3 lines plus 3 in `references/review-smoke-and-mr.md`. |

**C6. Finishing.** The set is finished when every member's progress
Status is `merged`; the engineer sets it after each merge, as today
(`merge-request/SKILL.md:137-141`). `progress.py set` shows the count;
`workflow` already runs `progress.py index` for "what is in flight"
(`workflow/SKILL.md:88`), unchanged.

## Anti-goals

- G1. No wildcard, no "every repository" value, no per-host opt-in, and
  no environment variable that turns pushing on.
- G2. No merge, no MR or PR creation, no tag, no release, no force push,
  no push of any branch but the current one, no push to a remote other
  than `origin`, under any setting.
- G3. The raw `git push` verb row, the settings deny and the sandbox
  network allowlist do not change. The only path is `brg-push run` from
  the Stop hook.
- G4. No auto push on harnesses other than Claude Code; `brg-harness`
  output is unchanged.
- G5. No new skill, no new stack, no new hook script, no new lint target.
- G6. No cross-repository writes from one session; no workspace or
  monorepo manager; no tracker sub-tickets per repository.
- G7. The site flow does not get its own autopilot profile.

## Open questions for the user

- Q1. Opt-in location. The request says "the repository's bearing.env",
  which does not exist. This spec uses the personal `bearing.env` listing
  repositories. Alternative: a tracked `.bearing/config.json` key the
  team agrees in an MR, required in addition to the personal key.
- Q2. Should `hotfix/*` branches be excluded from auto push? This spec
  allows them (a branch push, not a merge).
- Q3. Is the push result printed on the next prompt enough, or should
  the Stop hook also show a one-line `systemMessage` at once?
- Q4. One session per repository for a task set (this spec), or support
  one session across repositories with `--add-dir`, which needs the
  sandbox write list widened per session?
- Q5. Default stack for the site flow: `nextjs` (this spec), or a static
  generator, which Bearing has no stack lane for today.

## Acceptance criteria

1. With no `BEARING_AUTO_PUSH`, every existing test passes unchanged and
   no Bearing code path runs `git push`
   (`tests/unit/guard_deny_table.sh`, `tests/unit/autopilot_state.sh`).
2. `brg-push check` prints one line per condition and
   `push-check: 9 conditions, M met`; exits 1 on any unmet; exits 2
   outside a git repository and prints "0 conditions checked".
3. Opted in, on `feature/ABC-1-X`, clean, gate fresh, a request
   present: a Stop that passes the gate pushes to a local bare `origin`
   with exactly `--no-follow-tags --set-upstream origin HEAD:refs/heads/feature/ABC-1-X`;
   `push-result` records the sha; no tag reaches the remote.
4. Each of these refuses with its named condition and pushes nothing:
   `main`, `release/v1.2.0`, detached HEAD, dirty tree, stale gate, zero
   commits ahead, non-fast-forward remote, no request, a request for
   another sha, `bearing.env` newer than the session mark, repository
   not listed.
5. `brg-guard command 'bash /x/bin/brg-push run --id s'` exits 2;
   `brg-push check` and `brg-push request` are allowed.
6. `brg-config set auto-push x --user` (and `auto_push`, `AUTO.PUSH`)
   exits 2 and leaves `bearing.env` unchanged.
7. The pre-push hook, with an agent variable set: refuses without the
   opt-in (today's message), allows a fast-forward feature branch with
   it, refuses a tag ref, a protected branch and a non-fast-forward
   with it; both copies identical.
8. The autopilot `mr` gate passes when the upstream equals HEAD and
   `push-result` records it, and fails as today for any other upstream.
9. `make docs` reports the new flow count; `flow-steps.tsv` holds
   `site` rows; `brg-session next-step` returns the next `site` step
   when `.bearing/config.json` has `"flow": "site"` and the branch is a
   feature branch, and the `bugfix` step on a bugfix branch.
10. `progress.py set` prints one row per repository and the `set:` line,
    exits 1 on zero repositories or a missing path; `check` rejects a
    `## Repos` section with duplicate or missing order numbers.
11. Every row of the A8 table is changed as listed, and a test fails if a
    file in that table still carries an unqualified "never pushes"
    sentence.
12. `make lint-plugin-size` shows `bearing` at its pre-branch count plus
    2; every touched SKILL.md is 200 lines or fewer; `make check` ends
    with `check: passed`.
