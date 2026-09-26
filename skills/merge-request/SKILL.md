---
name: merge-request
description: 'Prepares the merge request for the current branch: gate run, commit audit, diff summary, MR description, ticket link, push command; never pushes. Use when asked to "prepare the MR", "write the PR description".'
argument-hint: "[target branch, default develop]"
allowed-tools: Read, Write, Grep, Glob, Bash(bash *bin/brg-tracker *), Bash(make:*), Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git branch:*), Bash(git fetch:*), Bash(git remote:*), Bash(mkdir -p .scratch), Bash(tail -40), Bash(go test:*), Bash(pnpm test:*), Bash(uv run pytest:*), Bash(./gradlew test:*), Bash(swift test:*), Bash(bash *bin/brg-state-path*), Bash(python3 *skills/session-handoff/scripts/progress.py*)
---

# merge-request

The engineer pushes and opens the MR in under a minute with what this
produces. It works in any git repository; a repository on the standard
only makes the inputs below quicker to find.

## Inputs

- branch: `git branch --show-current`; detached HEAD stops with "check
  out the branch to merge".
- task id: looks in the branch name (`[A-Z][A-Z0-9]*(-[0-9]+)+`); if
  absent, the state file `.bearing/state/<branch with / as _>.md` (`bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-state-path"` prints it); if absent, ask once; if
  none, proceed with no id and say so in the description and the report.
- target: looks in `$1`; if absent, `develop` when `origin/develop`
  exists; else `main`; else the HEAD branch from `git remote show
  origin`; else the current branch's upstream. Say which was used.
- gate: `make check` when the Makefile has a `check` target; if absent,
  the stack's native command (`go test ./...`, `pnpm test`, `uv run
  pytest`, `./gradlew test`, `swift test`) and the report says the gate
  is improvised (`new-repo` or `onboard-repo` install the Makefile).
- host: `git remote get-url origin` (`github.com` is github, a url
  containing `gitlab` is gitlab; otherwise `BEARING_GIT_HOST`, else gitlab);
  it decides the word (merge request or pull request), the template and
  the url pattern below.
- change template: `.gitlab/merge_request_templates/Default.md` or
  `.github/PULL_REQUEST_TEMPLATE.md` in the repository, by host; if
  absent, this skill's own `templates/mr.md`.
- clean tree: `git status --porcelain`; if dirty, list the files and ask
  once: the engineer commits first, or you continue describing only the
  committed diff (the description then says the tree had uncommitted
  changes and that they are not in the MR). With no one to answer, take
  the second. Never commit, stash or discard the engineer's changes
  yourself: what they have not committed is theirs to decide.
- `.scratch/`: created with `mkdir -p`; if `.gitignore` exists and lacks
  the line, say so.
- progress file: `docs/progress/<ID or branch with / as _>.md`, the
  committed summary other engineers read (the state file is local to this
  machine). Written by
  `python3 "${CLAUDE_PLUGIN_ROOT}/skills/session-handoff/scripts/progress.py"`
  in step 10, after the description; absent means it is created there.
- tracker: `bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-tracker" config`; `none`
  (or an absent env file) is reported as `tracker: none` under Verified,
  never under Not done.

## Steps

1. Preflight. Check the branch against
   `^(feature|bugfix|hotfix|chore|docs)/[A-Z][A-Z0-9]*(-[0-9]+)+-[A-Za-z0-9]+$`.
   A mismatch is not a stop: print the rename command under Noticed and
   continue. Resolve the task id and the clean tree as in Inputs. This
   skill describes the branch the engineer asked about as it stands: it
   adds no commit, and every number and file list below is for that
   branch.
2. Target as in Inputs; `main` only for `hotfix/` unless `$1` says
   otherwise. `git fetch origin <target>`; without a remote, diff
   against the local target branch and say so.
3. Diff: `git diff --stat <target>...HEAD` and `git log --oneline
   <target>..HEAD`. Zero files: stop, "0 files in diff between <target>
   and HEAD". Over 400 changed lines: continue, but the Risk section
   must propose the split.
4. Gate as in Inputs: `<command> 2>&1 | tail -40`. `make check` must end
   in `check: passed`; a native command must exit 0. When the diff
   changes the Makefile, the CI config or the test selection, or the
   README says the gate covers more than the target runs, also run the
   stack's full native suite and report both. A failure does not stop
   the write-up: the description and the report quote the failing tail,
   and the MR is reported as not ready.
5. Commits: every subject Conventional with `[ID]` when an id exists;
   no AI trailer in any body (`git log --format=%B`). List offenders;
   never rewrite history.
6. Description: fill the template from Inputs. Title is a commit subject
   with `[ID]` when there is one. Summary is why, not what. How to test
   is numbered and runnable. Verification is the gate tail verbatim,
   headed with the command that produced it. Checklist: tick only what
   you verified (`definition-of-done` output if it ran); leave the rest unticked
   with a reason. For UI changes, leave a screenshot placeholder and say
   so. Delete the instruction comments. Describe the branch as it
   is. If you would reshape it (drop, split or reorder commits, open from
   a trimmed branch), put that under Risk and in the report as advice
   with its commands, and say whether you ran the gate on that shape;
   the description, the diff numbers, the push command and the URL stay
   those of the current branch.
7. Prose: no em dashes, no self-praise, no sentence that only says the
   work matches the request.
8. Write to `.scratch/mr-<ID or branch>.md`, print it, then the output
   contract, and last: `git push -u origin <branch>` and the host's "new
   change" URL pattern: GitLab
   `<remote web url>/-/merge_requests/new?merge_request[source_branch]=<branch>`;
   GitHub `<remote web url>/compare/<target>...<branch>?expand=1` (or the
   `gh pr create --fill --base <target>` line, printed, never run).
9. Ticket: with a task id and a tracker, run `bash
   "${CLAUDE_PLUGIN_ROOT}/bin/brg-tracker" trace <ID> --branch <branch>
   --commits <list> [--tests ..] [--adr ..]` and report its line; exit 3
   means `tracker: none`, reported as such. The MR url is posted by the
   engineer after opening it: print `tracker-sync trace <ID> --mr <url>`
   under the push command, and the line that records it in the progress
   file: `progress.py write --task <ID> --mr <url>` (committed with the
   next change on the branch).
10. Progress file: `python3
   "${CLAUDE_PLUGIN_ROOT}/skills/session-handoff/scripts/progress.py" write
   --task <ID> --status "in review" --next "address review comments"`
   (add `--ticket <url>` when known). Leave it uncommitted and print the
   command that commits it (`git add <file> && git commit -m
   "docs(progress): [<ID>] in review"`); the engineer decides whether it
   goes in this MR (a hotfix to `main` usually should not carry it).

## Output contract

```
## MR | PR: <branch> -> <target> (<ID> | no task id)   host: gitlab | github
Branch name: ok | rename: <command>   Tree: clean | dirty (<N> files)
Diff: N files, +A -D (split proposed: yes | no)
Gate: make check: passed | <native command> (improvised): passed
Commits: N (offenders: K, listed)
Description: .scratch/mr-<ID or branch>.md
Ticket: trace posted to <KEY> | tracker: none
Progress: docs/progress/<ID>.md status in review (uncommitted; commit command printed)
Push: git push -u origin <branch>   MR | PR: <url pattern>
```

## Gotchas

- Never run `git push`, `glab mr create`, `gh pr create`, `git commit`
  (plain or `--amend`), `git rebase` or `git reset`. If asked, decline in
  one line and print the command.
- Change no tracked file to make a checklist item true (unskipping a
  test, adding a variable to `.env.example`): leave the item unticked and
  name the fix under Not done.
- A failing gate on a pre-existing issue still makes the MR not ready;
  report it under Not done, do not fix it in this MR.
- Do not tick "regression test" unless you opened the test file.
- The progress file is how the team sees the task is in review; the
  engineer commits it, never this skill, so the MR diff stays what they
  wrote. No skill sees the merge happen: after it, the
  engineer sets `--status merged` (or `abandoned` for a closed MR) on the
  base branch.
- An improvised gate proves less than `make check` (no lint, no
  gate-audit); the Verification section names it as improvised.
