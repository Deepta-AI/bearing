---
name: task-report
description: 'Writes the end-of-task report: Changed, Verified, Not done, Noticed, with evidence. Use when work is finished or someone asks for a summary of it: "write up what you did", "report back", "give me the status".'
argument-hint: "[task id or one-line task statement]"
allowed-tools: Read, Write, Grep, Glob, Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git show:*), Bash(git rev-parse:*), Bash(git merge-base:*), Bash(git archive:*), Bash(git worktree:*), Bash(tar:*), Bash(mkdir:*), Bash(make:*), Bash(go test:*), Bash(go vet:*), Bash(pytest:*), Bash(python3 -m pytest:*), Bash(npm test:*), Bash(npm run:*), Bash(pnpm test:*), Bash(pnpm run:*)
---

# task-report

A report is read by someone who was not in the session and will act on
it: paste it into a ticket, open an MR with it, or merge on the strength
of it. Its only job is to be true. Every line is backed by a command run
in this session or a file and line in the repository; everything else is
labelled as a claim or as not run.

Two modes. **Session**: report the work this session did. **Branch**:
report a branch or a piece of work someone asks about ("write up what's
been done on this branch"). Branch mode changes no code.

Not this: `session-handoff` records where a session stopped for the next
one; this reports what a task delivered.

## Inputs

- the task: `$ARGUMENTS`, the request, and the written ticket if the
  repository or the request has one (docs/tickets/, an issue file, the
  MR template). If none was ever stated, say "task not stated" under Not
  done rather than reconstruct it.
- what changed. Session: the files this session edited, checked against
  `git status --porcelain`. Branch: `git merge-base <default> HEAD`, then
  `git diff --stat <base>...HEAD` and `git log --format='%h %s%n%b' <base>..HEAD`.
- ownership: `git status --porcelain` at the start of the session (or,
  failing that, `git diff` compared with the edits you know you made).
- evidence: commands run in this session and the output seen. Nothing
  else counts.

## Steps

1. **Separate what is yours from what was already there.** Any modified
   or untracked path the session did not create or edit is foreign: a
   teammate's or an earlier session's. In branch mode the whole working
   tree is foreign; only commits `<base>..HEAD` are the branch. Read each
   foreign diff (`git diff <path>`) and say what it does and what
   committing it would do. Never list it under Changed, never include it
   in a commit command, and never revert, stash, check out or reset it,
   or tell the reader to: whose change it is and whether it ships is a
   decision for its owner.
2. **Find the yardstick.** Read the written task. List every acceptance
   criterion and judge each from the code with a file and line: met,
   partly met (say exactly what falls short), or not met. A unit mismatch
   (ms against seconds), a hard-coded number where configuration was
   asked for, and a bypass path (a missing header that skips the check)
   are the usual "partly" cases. When the documentation (README, runbook)
   and the code disagree, say which is right per the ticket.
3. **Treat claims as claims.** Commit messages, MR text, comments, TODOs
   and README statements ("load tested", "all criteria covered", "tests
   pass") are not evidence. Either confirm them from the repository or a
   command, or report them as unverified with what would verify them.
4. **Verify what ships, not your working tree.** Run the repository's
   own gate (the Makefile or CI target, else the test runner). If the
   working tree holds foreign edits, a green result there says nothing
   about the branch: a local edit can weaken a test or flip a default.
   Run the gate again on a clean copy of what would be merged, without
   touching the working tree:
   `mkdir -p <scratch>/head && git archive HEAD | tar -x -C <scratch>/head`
   (session mode: then copy your own changed files on top). Report both
   results when they differ, and which one CI will see. Name every test
   the gate skipped or deselected (markers, build tags, `-short`, CI-only
   suites) as not run, with what it would have proven.
5. **Probe the behaviour that matters most** when no test covers it
   directly: run the command, call the handler, print the header. Give
   the exact command line so the reader can repeat it, and the output.
6. **Count from the source.** Every number in the report (tests passed,
   criteria met, files changed) is taken from the command output or from
   the itemised list in the same report. Recount after the last edit; a
   summary line that disagrees with its own table is the first thing a
   reviewer catches.
7. **Shape it for where it goes.** The reader's destination decides the
   form; the evidence rules do not change.
   - MR description: a title line with the ticket id, one sentence of
     why, what the change does, what is not done against the ticket,
     what must happen before merge, how it was checked. Prose a reviewer
     reads, not a session log.
   - Ticket comment: lead with the ticket id and what the change does,
     with one example invocation that runs as given, then what is open.
   - Anything else: the four sections of the output contract.
   Put a blocker (data loss, a false green, the feature shipping off)
   first, above everything else.
8. **Close.** Session mode with nothing committed: end with a commit
   command for the engineer that stages your own paths by name (never
   -A, a dot or commit -a) and a message carrying the ticket id.
   Branch mode: no commit command. Nothing is committed, pushed or
   switched by this skill.

## Output contract

The content, in whatever shape step 7 chose:

```
## Changed
- path: what changed and why (session: yours only; branch: from <base>...HEAD)
## Verified
- the exact command, where it ran (working tree or clean HEAD copy), and its result; "not run" for anything skipped
## Not done
- each acceptance criterion not met or partly met, with file:line; anything asked and not delivered, and why
## Noticed (not fixed)
- foreign edits and what shipping them would do; unverified claims; bugs seen in passing that need their own ticket
```

No diff pasting, no praise, no closing offer, no em dashes. Nothing about
reviews, deploys, staging or production unless it happened in this
session.

## Gotchas

- The green run on a dirty tree. Tests passing in the working tree while
  a foreign edit is present is the most common false "verified". The
  clean-copy run in step 4 is cheap; skip it only when the tree is clean.
- The sweeping commit command. `git add -A` in the printed command ships
  a teammate's half-done edit under your ticket id.
- The helpful revert. "Run `git checkout -- file` if it was not
  intended" destroys someone's work when pasted. Name the owner question
  instead.
- The commit message as evidence. "All acceptance criteria covered" in a
  commit is the claim the report exists to check.
- A bug found while working that changes behaviour (wrong sort order,
  data loss) goes under Noticed with a concrete example from the repo's
  own data; fixing it silently inside another ticket is a scope violation.
  If you did fix it, it moves to Changed marked outside scope.
- "The runbook" or "the docs" may live outside the repository; editing a
  README section does not update them. Say where they live and give the
  text to paste.
- Not done is the section people skip and the one the lead reads first.
