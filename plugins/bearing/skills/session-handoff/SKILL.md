---
name: session-handoff
description: 'Saves session state for the next session on this branch: next steps, done, blockers, questions, files, gate, and a progress note. Use when asked to "save state", "write a handoff", "pause here" or before /clear.'
argument-hint: "[note to put first under Next]"
allowed-tools: Read, Write, Grep, Glob, Bash(git status:*), Bash(git diff:*), Bash(git branch:*), Bash(git log:*), Bash(git rev-parse:*), Bash(date:*), Bash(mkdir -p .bearing/state), Bash(bash *bin/brg-state-path*), Bash(python3 *skills/session-handoff/scripts/progress.py*)
---

# session-handoff

The SessionStart hook prints the first twenty lines of this file back next
time, so the top of the file carries the most useful facts. There are no
prerequisites: the file is written from whatever the session knows.

Two files, two readers. The state file is local: `.bearing/state/` is
ignored, so only this machine sees it; it is the detailed session log. The
progress file `docs/progress/<ID>.md` is committed on the task branch; it
is the shared summary a second engineer, a fresh clone or `workflow`
reads. Each branch writes only its own progress file, so they never
conflict. `scripts/progress.py` owns its format (`templates/progress.md`).

Not this: `client-handover` is the client pack at the end of an
engagement; this is a note for the next session on this branch.

Not this: `task-report` says what a task did; this says where a session
stopped and what to do first.

## Inputs

- repository root: `git rev-parse --show-toplevel`; if not a git
  repository, the current directory, and the file carries the line
  "not a git repository; Files touched is from this session's edits".
- branch: `git branch --show-current`; detached or absent: the file is
  named `.bearing/state/detached.md` and says so.
- task id: the branch name (`[A-Z][A-Z0-9]*(-[0-9]+)+`); if absent, the
  existing state file's title; if absent, the file is titled with the
  branch name.
- base branch: the existing state file's `Base:` line; if absent,
  `origin/develop` when it exists; else `main`; else the current
  branch's upstream; else no commit list, and the file says so.
- gate result: `.bearing/state/.check-passed` newer than the newest
  changed file means `passed`; the marker absent or older means
  `not run since edits`.
- state directory: `.bearing/state/`; created with `mkdir -p`.
- progress file: `docs/progress/<ID>.md`; without a task id, the branch
  name with `/` as `_`. Written by
  `python3 "${CLAUDE_PLUGIN_ROOT}/skills/session-handoff/scripts/progress.py"`,
  which creates it when it is missing (a task started before this file
  existed gets one on its first handoff).
- status: `blocked` when a blocker stops all progress; `in review` when
  the progress file already says so and the branch has not changed since;
  else `in progress`.

## Steps

1. Gather in one batch: branch, task id, `git status --porcelain`,
   `git diff --stat`, `git log --oneline <base>..HEAD`, and the gate
   result, each as in Inputs. `$ARGUMENTS`, when given, is the first
   line under Next.
2. Write or overwrite `.bearing/state/<branch with / as _>.md` (`bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-state-path"` prints it):

   ```
   # <ID> <PascalName>
   Updated: <date time>   Branch: <branch>   Gate: passed|not run since edits
   ## Next (do this first)
   - one to three concrete actions, most specific first
   ## Done
   - what landed, by commit or by file
   ## Blockers
   - what stops progress and who can unblock it
   ## Open questions
   - decisions the user still owns
   ## Files touched
   - path: one line each (from git status)
   ## Notes
   - anything the next session would otherwise rediscover
   ```
3. Keep it under sixty lines. Facts, not narrative.
4. Update the progress file from the same facts, in short form: `python3
   "${CLAUDE_PLUGIN_ROOT}/skills/session-handoff/scripts/progress.py" write
   --task <ID> --status <status> --next <first Next action> --add-done
   <item> (once per new Done item) --blocker <item> (once each, or
   none)`, plus `--add-decision <ADR path and one line>` for a decision
   recorded this session. Nothing secret, nothing from Open questions or
   Notes; those stay local.
5. Say whether the progress file has uncommitted changes (`git status
   --porcelain docs/progress`); it goes in the next commit. This skill
   does not commit.
6. Print the output contract.

## Output contract

```
## Handoff: .bearing/state/<branch with / as _>.md (N lines, limit 60)
Branch: <branch>   Task: <ID | none>   Base: <base>   Gate: passed | not run since edits
Next:
- <first action>
Files touched: N   Blockers: N   Open questions: N
Progress: docs/progress/<ID>.md (status <status>; uncommitted | committed)
```

## Gotchas

- Never write secrets, tokens or credentials into the state file, even if
  they were in the conversation.
- The state file is local and stays ignored; never commit it. The
  progress file is the shared one; never add it to `.gitignore`.
- The file is per branch. Switching branches switches state; say so if the
  user is about to switch.
- If the tree is clean and there are no open questions, the handoff is one
  line: "clean, next: <action>".
- Outside a git repository the file still gets written; it is the only
  record the next session will have.
