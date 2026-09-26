---
name: start-task
description: 'Starts work on a ticket: creates the branch from the right base with the task id, writes state and progress notes, restates the criteria. Use when asked to "start TASK-142", "pick up this ticket" or "create a branch".'
argument-hint: "<TASK-ID> [PascalName] [--type feature|bugfix|hotfix|chore|docs]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(bash *bin/brg-tracker *), Bash(git status:*), Bash(git branch:*), Bash(git switch:*), Bash(git fetch:*), Bash(git remote:*), Bash(git rev-parse:*), Bash(mkdir -p .bearing/state), Bash(bash *bin/brg-state-path*), Bash(python3 *skills/session-handoff/scripts/progress.py*)
---

# start-task

One branch, one state file, one progress file, the criteria restated.
Works in any git repository; nothing has to be scaffolded first.

The state file (`.bearing/state/`, ignored) is this machine's session log.
The progress file (`docs/progress/<ID>.md`, committed on the branch) is the
shared summary a second engineer or a fresh clone reads.

## Inputs

- repository: `git rev-parse --show-toplevel`; not a git repository
  stops with "run `git init` (or open the repository) and rerun".
- task id: `$1`; if absent, ask once for it.
- tracker and prefix: `bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-tracker"
  config` (the `tracker:` and `id prefix:` lines; `BEARING_TASK_ID_PREFIX`
  from the environment or `~/.config/bearing/bearing.env` wins, else the
  adapter's own key shape); if the script is absent, the CLAUDE.md
  snapshot (`Task tracker:` line); if nothing names a prefix, accept any
  id matching `[A-Z][A-Z0-9]*(-[0-9]+)+` and say so. With `tracker: none`
  and no id from the user, use `NOTASK-<n>` where n is one more than the
  highest `NOTASK-` number in `git branch -a` (1 when there is none), and
  say so; `none` is never a stop.
- type: `--type`; if absent, `bugfix` when the task reads as a defect,
  else `feature`; say which was chosen.
- base branch: `develop` for feature, bugfix, chore, docs and `main` for
  hotfix, when those branches exist; else `main`; else the HEAD branch
  from `git remote show origin`; else the current branch. Say which.
- name: `$2`; if absent, ask for a two to four word summary and
  PascalCase it.
- state directory: `.bearing/state/`; created with `mkdir -p`. If
  `.gitignore` exists and lacks `.bearing/state/`, add the line and say
  so; if there is no `.gitignore`, say the directory is untracked only
  by convention (`onboard-repo` installs the standard `.gitignore`).
- acceptance criteria: pasted by the user in the request; if absent, the
  state file says "unknown, ask" and the Next section asks for them.
- progress file: `docs/progress/<ID>.md`, written by
  `python3 "${CLAUDE_PLUGIN_ROOT}/skills/session-handoff/scripts/progress.py"`;
  if the script is absent, write the file by hand from
  `skills/session-handoff/templates/progress.md` and say so.

## Steps

1. Validate the id: against `BEARING_TASK_ID_PREFIX` when set (the id must
   start with `<PREFIX>-`), else the generic shape
   `[A-Z][A-Z0-9]*(-[0-9]+)+`. With `tracker: none`, a user-chosen id or
   `NOTASK-<n>` as in Inputs.
2. Working tree must be clean (`git status --porcelain` empty). If not,
   stop and list the files; never stash for the user.
3. Base branch as in Inputs. `git fetch origin <base>` then branch from
   `origin/<base>` when the remote exists, else from the local base.
4. Name: `<type>/<ID>-<PascalName>`. Refuse spaces and lowercase starts.
5. `git switch -c <branch> <base>`.
6. Write `.bearing/state/<branch with / as _>.md` (`bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-state-path"` prints it):

   ```
   # <ID> <PascalName>
   Started: <date>   Base: <base>
   ## Acceptance criteria
   - (from the task; write "unknown, ask" if none were given)
   ## Done
   ## Next
   - restate the task and confirm the criteria with the user
   ## Blockers
   ```
7. Write the progress file: `python3
   "${CLAUDE_PLUGIN_ROOT}/skills/session-handoff/scripts/progress.py" write
   --task <ID> --title <PascalName> --status started --criteria <N |
   unknown> --next <first action>` (add `--ticket <url>` when the tracker
   gives one). It is committed with the first commit on the branch; this
   skill does not commit, so the output contract says so.
8. Print the output contract; the next skill is Superpowers
   `brainstorming` if the request is vague, else start coding
   test-first.

## Output contract

```
## Task: <ID> <PascalName>
Branch: <type>/<ID>-<PascalName> from <base> (origin | local)
State: .bearing/state/<file>   Criteria: N | unknown, ask
Progress: docs/progress/<ID>.md (status started; commit it with the first commit)
Tracker: <name | none> (prefix <P> | any id)
Next: <skill or action>
```

## Gotchas

- Never create the branch from a dirty tree, and never from another task
  branch unless the user says the tasks stack.
- The tracker is not queried over the network here; the user pastes the
  title and criteria (`tracker-sync get <ID>` fetches them when a tracker
  is configured). Do not invent acceptance criteria.
- Never add `docs/progress/` to `.gitignore`; only `.bearing/state/` is
  ignored. The progress file exists to be committed and shared.
- A repository with only `main` gets its task branches from `main`; the
  report says so, and `onboard-repo` documents the branching model when the
  team wants `develop`.
