---
name: branch-review
description: 'Code review of a branch, MR, patch or path with stack checklists, every Critical and High finding independently verified, and merge verdict. Use when asked to "review this", "review the MR" or "look over my changes".'
argument-hint: "[commit range, patch file or path; default origin/develop...HEAD] [--engine gstack|bearing]"
allowed-tools: Read, Grep, Glob, Skill, Agent, Bash(git diff:*), Bash(git log:*), Bash(git show:*), Bash(git status:*), Bash(git rev-parse:*), Bash(git remote:*), Bash(git worktree list:*), Bash(git archive *), Bash(git apply --check *), Bash(git apply --directory=.scratch/review/*), Bash(tar -x -C .scratch/review/*), Bash(make -C .scratch/review/*), Bash(rm -rf .scratch/review/*), Bash(ls:*), Bash(mkdir -p .scratch/review/*), Bash(bash *bin/brg-checklists *)
---

# branch-review

The engine finds; a verifier who never saw the engine's reasoning
confirms. gstack `/review` (specialist reviewers in parallel, an
adversarial pass, a confidence gate) is the engine whenever it is
installed. This skill adds what this standard needs around it:
the stack checklists applied item by item, an independent verifier on
every Critical and High, the project's own check run against the change
without touching the tree, and a merge verdict.

Not this: the official `/code-review` scores findings on a GitHub PR with
several reviewers and posts an attribution line; `gsd-code-review`
reviews a GSD phase. Running gstack `/review` directly also picks up the
checklists (the session start lists them) but skips the independent
verification.

## Inputs

- Target, the first argument or what the request names:
  - a commit range: reviewed as given;
  - a patch or diff file (`mr-51.patch`): the change is that file on top
    of `HEAD`;
  - a path ("look over app/webhooks"): the files as they stand and what
    they call, with no diff; the checklists apply to the whole path;
  - nothing: `origin/develop...HEAD`, else `origin/main...HEAD`, else (no
    remote) `HEAD~1` plus the working tree (`git diff HEAD~1`). A
    repository with one commit has no `HEAD~1`: review that commit as a
    path review of the files it holds and say so.
  Not a git repository: one question for a diff file or a path. Nothing
  to review: stop with "provide a commit range, a diff file or a path".
- Checklists: `bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-checklists" --range <range>`
  prints the universal checklist and one per stack the diff touches
  (react, nextjs, react-native, node, go, python, data-pipeline, android, ios,
  flutter, infra, database). For a patch file or a path, pick the
  checklists by the stacks of the files it touches. If the plugin root
  is unknown, the universal checklist at `references/universal-checklist.md`
  stands in and the report says "universal checklist only".
- Engine: `--engine`; if absent, `gstack` when
  `~/.claude/skills/gstack/review/SKILL.md` exists, else `bearing` (the
  `reviewer` agent, which has Read, Grep and Glob and no shell).
- Collected change: `.scratch/review/<slug>/`, written by step 2 before
  any agent runs, where `<slug>` is the range, patch name or path with
  every character outside `A-Za-z0-9._` turned into `-`. The agents have
  no shell, so this folder is how they see the change.
- Project check: the make target the README, Makefile or CONTRIBUTING
  names (check, test); none named means "not run: no check
  command in the repository".
- Merge rules: `AGENTS.md`, `CONTRIBUTING.md` and the ADRs the change
  touches; commit conventions from the same files, else the universal
  items (Conventional Commits, a task id, no AI trailer).

## Steps

1. Resolve the target as in Inputs. For a range or patch,
   `git diff --stat <range>` or `git apply --check --stat <patch>`; zero
   files means stop with "0 files in diff, nothing to review".
2. Collect the change for the agents, with this skill's own git grants:
   `mkdir -p .scratch/review/<slug>`, then for a range
   `git diff --output=.scratch/review/<slug>/diff.patch <range>`,
   `git diff --stat --output=.scratch/review/<slug>/stat.txt <range>`,
   `git diff --name-only --output=.scratch/review/<slug>/files.txt <range>`
   and `git log --format='%h %s' --output=.scratch/review/<slug>/log.txt <range>`.
   A patch file or path is passed as is. Resolve the checklists and
   print their counts line.
3. Run the project check against the change in a throwaway copy, so
   the working tree, the branches and the worktree list end exactly as
   they began: `mkdir -p .scratch/review/<slug>/tree`, then
   `git archive <rev> | tar -x -C .scratch/review/<slug>/tree`, where
   `<rev>` is the head of the range, `HEAD` for a patch or a path, or
   the base when the range includes the working tree; then, for a patch
   or that working-tree range,
   `git apply --directory=.scratch/review/<slug>/tree <patch or diff.patch>`;
   then `make -C .scratch/review/<slug>/tree <target>`. Record the
   command and its counts line. Keep the copy until step 6 has used it
   (a failing input can be tried there), then
   `rm -rf .scratch/review/<slug>/tree`. A check that needs what git
   does not hold (`node_modules`, a database) is "not run" with the
   reason. Never test a change with git am, a new worktree, a new branch,
   a stash, or git apply into the working tree.
4. Run the engine.
   - gstack: invoke the `review` skill (Skill tool) with this as its
     argument: "Base: <base of the range>. In addition to your checklist,
     apply every item of these files and report each as a finding or
     'checked, none found': <checklist paths>. Report only: apply no
     fix, write no file outside .scratch/review, do not commit or push."
     Keep its findings as reported, with its severity mapped: CRITICAL
     to Critical or High by its own wording, INFORMATIONAL with
     confidence 7 or more to Medium, the rest to Low.
   - Bearing: fork `reviewer` (Agent tool) with the target, the
     paths under `.scratch/review/<slug>/`, the merge rules and the
     checklist paths.
   Then hold the change to its own claims: the commit message, the docs
   it edits and the ADRs it touches. A claim the code does not keep is
   a finding.
5. Independent verification. For every open Critical and High, fork one
   `verifier` (Agent tool), all in one message so they run in
   parallel, at most 12; beyond that, the 12 most severe are verified and
   the rest listed as "not verified". Each verifier gets only the
   `path:line`, the one-sentence claim, the failure scenario and the path
   of `.scratch/review/<slug>/diff.patch` (or the path under review);
   never the engine's reasoning, its confidence or the other findings.
6. Merge the verdicts. CONFIRMED stays at the verifier's severity.
   REFUTED moves to "Dropped" with the verifier's quoted defence.
   UNCERTAIN moves to "Questions". Medium and Low stay as the engine
   reported them, marked unverified. For each confirmed finding, say
   whether the project check from step 3 passes with it present; a
   suite that passes with a blocking bug is itself a finding (name the
   test that looks as if it covers the case and why it cannot fail).
7. Check the commits in the range (for a patch file, its Subject line)
   against the conventions. Decide the
   verdict: any confirmed Critical or High, or a merge rule broken,
   means not ready. Print the contract.

## Output contract

```
## Review: <target> (<N> files) by <gstack /review | reviewer>
Verdict: not ready to merge (<n> blocking: 1, 3) | ready after <items> | ready to merge
Checks: <command> with the change applied: <counts line> | not run (<reason>)
brg-checklists: <its counts line>
Verified: C confirmed, R refuted, U uncertain of V Critical and High (K not verified)
1. [Critical] path:line  claim   (verified, blocking)
   Failure: <the input or sequence, and what the user sees>
   Evidence: <the verifier's deciding quote, path:line>
   Tests: <passes with this bug | caught by name>
   Fix: <in words or a snippet; never applied>
2. [Medium] path:line  claim   (unverified)
## Checked, none found
- checklist items that passed, one line each
## Questions
- UNCERTAIN findings, with what the verifier could not trace
## Dropped
- REFUTED findings, with the verifier's quoted defence
## Not reviewed
- ...
## Commits
- ok | offenders listed
## Left behind
- .scratch/review/<slug>/ (notes only) | nothing
```

For a path review, "merge" in the verdict reads as the step the user
named ("switch on", "release").

## Gotchas

- `reviewer` and `verifier` have no shell (plugin agents cannot
  carry a hook, so Read, Grep and Glob is the only read-only guarantee).
  Anything they need from git is collected in step 2; an agent sent a
  range without the folder reviews nothing.
- The verifier sees one finding, not the conversation. Passing it the
  engine's reasoning turns verification back into agreement.
- "Verified" means an independent agent quoted the lines that make the
  failure real. Re-reading a finding in the same context is not
  verification and is never labelled so.
- A review is read only. gstack `/review` offers to fix; this skill tells
  it not to, and never edits a tracked file, commits, or creates a
  branch or worktree. Fixes appear in the report; applying them is a
  separate request.
- Bearing's guard blocks `git worktree remove` and `git branch -D`, so a
  worktree or branch made to test a change outlives the run. The
  throwaway copy in step 3 is plain files under `.scratch/` and goes
  with one `rm -rf`.
- Style that a formatter or linter decides is never a finding.
- Generated files (`*.gen.ts`, `*.pb.go`, sqlc output, lockfiles) are not
  reviewed; list them under Not reviewed.
- This skill does not replace a security review; recommend `/cso` or
  `claude-security` when auth, payments, PII or external input changed.
