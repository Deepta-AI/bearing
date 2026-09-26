---
name: tracker-sync
description: 'Creates and updates tickets in the configured tracker (Jira, GitLab, GitHub, REST or none): create, sync the backlog, move status, link MRs. Use when asked to "create the tickets", "sync to Jira" or "move TASK-142".'
argument-hint: "create <type> <title> | update <KEY> [--status s] [--assignee me] | sync [backlog] | trace <KEY> [--mr url] | get <KEY> | list | config"
allowed-tools: Read, Grep, Glob, Bash(bash *bin/brg-tracker *), Bash(git branch:*), Bash(git log:*), Bash(git remote:*), Bash(ls:*)
---

# tracker-sync

Every deterministic call goes through `bin/brg-tracker` from the plugin
(`bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-tracker" ...`). It reads
`BEARING_TRACKER` from the environment, then `~/.config/bearing/bearing.env`,
and dispatches to the adapter (`bin/brg-rest`, `bin/brg-jira`,
`bin/brg-gitlab`, `bin/brg-github`). This skill decides what to create or
change, runs the script, and reports. Credentials never enter the
conversation: the adapters read them from the env file and never print
them. This skill calls `bin/brg-tracker` only, never an adapter directly.

## Inputs

- Tracker config: `bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-tracker" config`
  (environment first, then `~/.config/bearing/bearing.env`). If the
  tracker is `none` (or the env file is absent), say once that the
  workflow runs without a tracker, skip every ticket step with the note
  `tracker: none`, and stop; this is never an error. If the tracker is set
  but a credential is missing, the script says which key; print
  `templates/user/bearing.env` from the plugin root and where it lives,
  and stop. This is the one stop: it names the file and never asks for a
  paste.
- Script: `bin/brg-tracker` at the plugin root; always present.
- Key shape: from `config` (`id prefix:` line). Jira `<project>-N`
  (`PROJ-142`), GitLab `GL-N`, GitHub `GH-N`, a REST tracker whatever key
  its server returns (use it as printed, never guess its shape); `BEARING_TASK_ID_PREFIX` overrides what branch names
  carry.
- Story text for `create`: looks in `docs/product/backlog.md`; if absent,
  builds the description from a pasted narrative, or from the title alone
  with a `Description: pending` line.
- Backlog for `sync`: `$1` when given, else `docs/product/backlog.md`; if
  absent, offers to create tickets from a pasted list, from
  `docs/testing/test-cases.md`, or one at a time with `create`;
  `backlog` produces the fuller backlog.
- Test cases for `sync`: looks in `docs/testing/test-cases.md`; if absent,
  the test case pass is skipped and reported as 0.
- Git facts for `trace`: branch, remote and commits from git; an MR url
  comes from `--mr` or the git host's pattern, else the field is left off.
- The command surface, identical for every tracker (exit codes: 0 done,
  1 failed with a one-line reason, 2 usage, 3 skipped because the
  tracker is `none`, write commands only; adapter facts such as the
  hierarchy, status names and what "link" means on GitHub are in
  `docs/TRACKERS.md` of the plugin, with the REST tracker protocol
  and `bin/brg-rest` subcommands):

  ```
  brg-tracker config
  brg-tracker me | get <KEY> | resolve <KEY>
  brg-tracker list [--type t] [--status s] [--q text]
  brg-tracker create --type <epic|story|task|bug|testcase> --title <s>
              [--description-file f] [--parent KEY] [--priority p]
  brg-tracker update <KEY> [--status name] [--assignee me|email|login]
              [--title s] [--description-file f]
  brg-tracker comment <KEY> (<text> | --file f)
  brg-tracker link <KEY> <relates|blocks> <KEY2>
  brg-tracker trace <KEY> [--branch b] [--mr url] [--commits a,b] [--tests ..] [--adr ADR-nnnn]
  ```

## Steps

1. Setup check: `brg-tracker config`, then `brg-tracker me`. `none`:
   report and stop as in Inputs. A failure names the missing key or the
   unreachable host; print the env template and stop.
2. `create <type> <title>`: build the description from the story
   (narrative, criteria with their `AC-` ids, non-goals) into a temp file
   under `.scratch/`, then `brg-tracker create --type <type> --title
   "<title>" --description-file <f> [--parent KEY] [--priority p]`.
   `--parent` is the epic for a story, the story for a bug or task, the
   scenario or story for a test case; the adapter maps it. Print the
   returned key.
3. `sync [backlog]`: read the backlog. For each epic and story without a
   `Ticket:` line, create it (epics first, then stories with `--parent
   <epic key>`), then write the returned key back into the backlog as
   `Ticket: <KEY>` so the mapping is committed. Then test cases from
   `docs/testing/test-cases.md` the same way (`--type testcase --parent
   <story key>`). No backlog: offer the three sources under Inputs; a
   pasted list creates one story per line (no parent) and prints the keys
   for the user to keep. Print counts: created, already linked, failed.
4. `update <KEY> ...`: `brg-tracker update` with `--status`,
   `--assignee`, `--title`, `--description-file`. Status names are matched
   case-insensitively against what the tracker offers; an unknown name
   stops with the adapter's list.
5. `trace <KEY>`: gather branch (`git branch --show-current`), MR url
   (argument, or the host pattern from `git remote -v` plus the branch),
   commits (`git log --format=%h origin/develop..HEAD`), test case ids
   (grep `TC-` in changed test files), ADR ids from the diff; run
   `brg-tracker trace <KEY> --branch ... --mr ... --commits ... --tests
   ... --adr ...`. Run this from `merge-request` after the description is
   written; exit 3 there means "tracker: none", reported, not a failure.
6. `get`, `list` and `config`: print what the script returns.
7. Report in the AGENTS.md shape with every key touched.

## Output contract

```
tracker: <rest | jira | gitlab | github | none> (<command>)
<key> <type> "<title>" status=<name> assignee=<name>
created N, updated N, comments N, links N, failed N, skipped N
```

With `none` the second and third lines are replaced by one line:
`tracker: none (set BEARING_TRACKER in ~/.config/bearing/bearing.env); ticket
steps skipped`.

## Gotchas

- Never call an adapter directly and never read `bearing.env` into the
  conversation; `config` prints everything that is safe to show. What
  the generic surface does not cover (REST tracker labels, points,
  due dates, `statuses`) is `bin/brg-rest` run by the engineer, documented
  in `docs/TRACKERS.md`.
- `none` is a configuration, not a failure: no ticket step may error, ask
  for credentials, or invent a key. Branches then carry a user-chosen id
  or `NOTASK-<n>` (`start-task`).
- `create` with an unknown type is rejected by the script before the
  call; the five generic types are all any adapter accepts.
- Bulk creation is idempotent only through the `Ticket:` lines in the
  backlog; never run `sync` on a backlog with uncommitted edits.
- Do not move a ticket to a done status from here unless the MR is merged;
  `In Review` is the furthest `merge-request` goes.
- On GitHub, `link` is a pair of cross-reference comments, and on GitLab
  and GitHub a status is a label; the report says so rather than claiming
  a workflow transition.
