---
name: start-task
description: 'Starts work on a ticket: creates the branch from the right base with the task id, writes state and progress notes, restates the criteria. Use when asked to "start TASK-142", "pick up this ticket" or "create a branch".'
argument-hint: "<TASK-ID> [PascalName] [--type feature|bugfix|hotfix|chore|docs]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(bash *bin/brg-tracker *), Bash(git status:*), Bash(git branch:*), Bash(git switch:*), Bash(git fetch:*), Bash(git remote:*), Bash(git rev-parse:*), Bash(git log:*), Bash(git tag:*), Bash(git describe:*), Bash(git show:*), Bash(git stash list:*), Bash(git worktree:*), Bash(git merge-base:*), Bash(git diff:*), Bash(git grep:*), Bash(git for-each-ref:*), Bash(git config --get:*), Bash(git check-ignore:*), Bash(make:*), Bash(mkdir -p .bearing/state), Bash(bash *bin/brg-state-path*), Bash(python3 *skills/session-handoff/scripts/progress.py*)
---

# start-task

One branch at the base the work will actually ship from, a clean place to
work on it, a baseline, and the criteria restated and checked against the
repository. Works in any git repository; nothing has to be scaffolded.

A branch cut from the wrong base is the expensive mistake here: it either
lacks code the ticket depends on or carries unreleased code into a release.
Every step below exists to catch one of those, or to keep the engineer's
own uncommitted work safe.

## Inputs

- repository: `git rev-parse --show-toplevel`; not a git repository stops
  with "run `git init` (or open the repository) and rerun".
- task id: `$1`, or the id in the request; if absent, ask once.
- tracker and prefix: `bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-tracker" config`
  (`tracker:` and `id prefix:` lines; `BEARING_TASK_ID_PREFIX` wins); else
  the CLAUDE.md `Task tracker:` line; else any id matching
  `[A-Z][A-Z0-9]*(-[0-9]+)+`, and say so. With `tracker: none` and no id,
  use `NOTASK-<n>` (one above the highest in `git branch -a`).
- repository conventions: CONTRIBUTING.md, RELEASING.md, README.md, a
  branching or release section in docs/, and the deploy configuration
  (deploy/, k8s/, helm values, a workflow that deploys on a tag). Their
  naming and base rules override the defaults below; where they
  contradict what the history shows, the history wins and the report says
  so.
- type: `--type`; else `hotfix` when the request is about production being
  wrong now, `bugfix` for other defects, else `feature`; say which.
- name: `$2`; else derive a two to four word PascalCase summary from the
  request and say so (ask only if the request gives nothing to name).
- acceptance criteria: as the user gave them; absent ones are "unknown,
  ask", never invented.

## Steps

1. **Validate the id** against the prefix or the generic shape.
2. **Look for existing work on the ticket.** Branch names lie by
   omission: search commit messages too. `git branch -a --list`, `git
   worktree list` and `git log --all -i --grep=<ID> --format='%h %D %an
   %s'`, all case-insensitive (`abc-12` and `ABC-12` are one ticket; a
   branch named after the feature whose commits carry the id is work on
   it). If any exists, do not create a second silently: report the
   ref, author, last commit and what it was cut from, and either reuse it
   or create the new one and raise the duplicate as the first question.
   Never delete, rename or reset someone else's ref, and never hand the
   user a command that does before its author has agreed.
3. **Refresh and measure the base.** `git fetch origin` (all branches and
   tags). If it fails, say so in the report with the error, and that every
   `origin/*` ref is only as fresh as the last successful fetch. Never
   claim "latest" without a fetch that succeeded.
   - feature, bugfix, chore, docs: base is `origin/develop` when develop
     exists, else `origin/main`, else the remote HEAD branch. Never the
     local copy: compare them (`git log --oneline develop..origin/develop`)
     and report what the local branch lacks. If the request leans on
     existing code ("the query we already have"), find it and confirm it
     exists at the chosen base.
   - hotfix: base is **what production runs**, not whatever branch the docs
     call production and not the newest tag. Find the deployed version from
     the deploy config pin at the tip of the release branch, and read its
     history (`git log -p --oneline origin/main -- deploy/`): a release that
     was rolled back leaves a newer tag behind while the pin moved back.
     Only with no pin, fall back to `git describe --tags --abbrev=0
     origin/main` and say it is a guess. Then `git log --oneline
     <tag>..origin/main`.
     Empty: branch from `origin/main`. Not empty: main carries unreleased
     work; branch from the tag, list the commits a hotfix from main would
     have shipped, and say that merging the hotfix into main and releasing
     from there ships them too, so how to release (tag a patch from the
     hotfix branch, or revert on main first) is a question for the user,
     not decided here.
     Two more hotfix checks a generalist skips. The version: `git tag -l`;
     if the next patch after the production tag already exists (a
     rolled-back release, say), the hotfix cannot reuse that number, so
     name the next free one and flag that it will not contain the skipped
     release's changes. The fix may already exist: `git diff <tag>
     origin/develop -- <files of the defect>` and `git log <tag>..origin/develop
     -- <those files>`. If develop already fixed it, the hotfix is a
     cherry-pick (with -x, run by the engineer) of that commit (say whether it touches
     only those files), and "merge back to develop" becomes a no-op to
     confirm, not a second fix. If develop has the same defect, the fix
     must reach develop too; say which. Also list other open `hotfix/*`
     branches from the same tag: two hotfixes aiming at one version
     collide.
   - A task that stacks on another task branch only when the user says so.
4. **Create the branch without touching the engineer's work.** Name:
   `<type>/<ID>-<PascalName>` unless the repository's convention differs.
   Always `--no-track`: a branch created from `origin/develop` otherwise
   tracks develop, and with `push.default=upstream` (check `git config
   --get push.default`) a bare push lands on develop. The upstream is set
   on the first push to `origin/<branch>`, which the engineer runs.
   - Clean tree (`git status --porcelain` empty): `git switch --no-track -c
     <branch> <base>`.
   - Dirty tree: never stash, commit, discard or carry the changes over, and
     do not stop to ask. `git worktree add --no-track -b <branch> <path>
     <base>` with `<path>` beside the repository (`../<repo>-<ID>`); if it
     must sit inside, add it to `.git/info/exclude` so the engineer's
     checkout does not show it. Their files stay exactly where they were.
     Report the path.
5. **Baseline.** In the new branch's tree (the worktree when step 4 made
   one, never the dirty checkout), run the repository's gate (`make check`
   or the test command the README names) and record passed, failed,
   skipped and xfailed counts. A failure at the base is not the
   engineer's: name the failing tests and whether they touch the ticket's
   area. "Green" can hide the defect that matters: read the reason on every
   skip and expected failure, and when one covers code the ticket builds
   on, say what it means for the ticket (new code built on a function with
   a known expected failure inherits that bug). If the gate
   cannot run here, say "baseline not run" and why. Report only numbers the
   run printed.
6. **Check the criteria against the repository.** Restate each criterion
   as given, none dropped, merged or added. Then grep the ADRs
   (docs/adr, docs/decisions), README and the code for rules the criteria
   touch (money and units, naming, formats, API contracts, rounding), **at
   the base** (`git grep <term> <base> -- docs`), not in a stale checkout
   that may lack the newest decision. Follow the chain: an ADR's own status
   line is often not updated when a later one supersedes it, so grep for
   later ADRs that cite its number and apply the latest one, scope
   included (a rule superseded only for one kind of export still binds the
   rest). An
   Accepted ADR or documented rule that a criterion contradicts is an open
   question for the ticket owner, quoting both sides; do not silently adopt
   either, and do not edit the ADR. Your own extra checks go under a
   separate "suggested" heading.
7. **Notes**, all in the new branch's tree. Local session state: `bash
   "${CLAUDE_PLUGIN_ROOT}/bin/brg-state-path" <branch>`, run there, prints
   the path under `.bearing/state/`; `mkdir -p .bearing/state`
   and write the id, base (ref and commit), criteria, questions and next
   step. Keep it out of git through `.git/info/exclude`, not a `.gitignore`
   edit, so the branch starts with no unrelated diff. The shared progress
   file: `python3
   "${CLAUDE_PLUGIN_ROOT}/skills/session-handoff/scripts/progress.py" write
   --task <ID> --title <PascalName> --status started --criteria <N | unknown>
   --next <first action>`, written in the new branch's tree; it is committed
   with the first commit on the branch, not here. If the script is absent,
   skip it and say so.
8. **Stop there.** No implementation, no commit, no push, no tag. The next
   step is Superpowers `brainstorming` if the request is vague, else
   test-first work on the branch.

## Output contract

```
## Task: <ID> <PascalName> (<type>)
Branch: <branch> at <short sha> from <ref> (<why this base>); no upstream yet
Where: <this checkout | worktree path>; your uncommitted work: <untouched at ... | none>
Fetch: <ok | failed: error; origin refs as of last fetch>
Base check: <what local lacked | commits on main not in production | nothing>
Existing work on the ticket: <none | ref, author, and what was done>
Baseline: <command>: <n passed, n failed (names)> | not run: reason
Criteria (as given): 1..N
Conflicts with the repository: <ADR/rule vs criterion, as questions> | none
Questions: <each, with the working assumption>
Hotfix: <release question>; version <next free tag>; <cherry-pick sha | new fix>; develop <has it | needs it>
Next: <skill or action>; push with `git push -u origin <branch>` when ready
```

## Gotchas

- "main is production" in a document is a claim; the deploy pin and its
  history are the evidence, and the newest tag is not. Check them for
  every hotfix.
- An ADR that says Accepted may be superseded by a later one that never
  went back to edit it. Read the whole decisions folder at the base.
- A dirty tree is the normal case for a hotfix interruption. A worktree
  keeps the engineer's work untouched; a stash is a place work gets lost.
- `git switch -c x origin/develop` sets develop as the upstream unless
  `--no-track` is given.
- A fetch that fails silently turns "from the latest develop" into a false
  statement. Report the failure.
- The tracker is not queried over the network here; `tracker-sync get <ID>`
  fetches title and criteria when a tracker is configured.
- Never ignore `docs/progress/`; it exists to be committed and shared.
