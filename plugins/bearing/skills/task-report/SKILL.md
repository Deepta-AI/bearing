---
name: task-report
description: 'Reports a finished task under four headings: Changed, Verified, Not done, Noticed. Use when asked to "write up what you did", "report back", "summarise the work", "give me the status" or at the end of any task.'
argument-hint: "[task id or one-line task statement]"
allowed-tools: Read, Grep, Glob, Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git rev-parse:*)
---

# task-report

Four headings, always in this order, always all four. An empty section
says "nothing" in one line. There are no prerequisites: the report is
printed from what the session did.

Not this: `session-handoff` records where a session stopped for the next
one; this reports what a task delivered.

## Inputs

- changed files: `git status --porcelain` and `git diff --stat`; if not a
  git repository, the files this session edited, and the report opens
  with "not a git repository; Changed is from this session's edits".
- commits: `git log --oneline` for commits made this session; if none,
  the commit command is printed at the end.
- verification: the commands run in this session and the output seen;
  nothing else counts.
- the task: `$ARGUMENTS` or the request as given; if it was never
  stated, say "task not stated" under Not done rather than reconstruct
  it.

## Steps

1. Gather in one batch: `git status --porcelain`, `git diff --stat`, the
   commits made this session, and the list of commands run with the
   output seen. Print "N files changed, M commits, K commands run".
2. Changed: from `git status` and `git diff --stat` only; one line per
   path with what changed and why, grouped by feature, not by file type.
   Never a file you did not change.
3. Verified: the exact command and the tail of its output. Executed in
   this session with output you saw, nothing else; a test you believe
   passes but did not run goes under Not done as "not run".
4. Not done: what was asked and not delivered, and why.
5. Noticed (not fixed): things seen in passing that belong in another
   task. A Noticed item you already fixed moves to Changed with "outside
   scope", or is reverted.
6. Print the shape. No diff pasting, no restating the task, no praise,
   no "as requested", no closing offer, no em dashes, short sentences.
   Name the commit when one exists; else end with the commit command
   for the engineer.

## Output contract

```
## Changed
- path: what changed and why, one line each (group by feature, not by file type)
## Verified
- the exact command run and the tail of its output; "not run" where it was not run
## Not done
- what was asked and not delivered, and why
## Noticed (not fixed)
- things seen in passing that belong in another task
```

## Gotchas

- Not done is the section people skip and the one the lead reads first.
- A Noticed item with a fix already applied is a scope violation; move it
  to Changed and say it was outside scope, or revert it.
- Outside a git repository the report is still printed; it just names its
  source.
