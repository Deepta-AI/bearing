---
name: onboard-repo
description: 'Brings an existing repository onto the team conventions (Makefile, hooks, CLAUDE.md, rules) without overwriting; conflicts land beside the file. Use when asked to "onboard this repo" or "adopt the standard".'
argument-hint: "[--stack <id>] [--apply-new]"
allowed-tools: Read, Grep, Glob, Skill, Bash(bash *bin/brg-adopt *), Bash(bash .githooks/install.sh), Bash(ls:*), Bash(git status:*), Bash(git rev-parse:*), Bash(git init:*), Bash(diff:*), Bash(make -n:*)
---

# onboard-repo

`bin/brg-adopt` does the copying with three outcomes per file: added,
kept (identical), or conflict (written as `<file>.bearing-new`). This skill
runs it, then walks the conflicts with the engineer. It is the entry
point for a repository that has none of the standard's files, so it
assumes none of them.

## Inputs

- repository: `git rev-parse --show-toplevel`; if not a git repository,
  ask once whether to run `git init`; on no, copy the files anyway
  and list `core.hooksPath` under Not done.
- working tree: `git status --porcelain`; if dirty, list the files and
  ask once: commit first (recommended, the adoption diff stays readable)
  or continue; on continue the report lists those files under Noticed.
- stack: `--stack`; if absent, detected from `go.mod`, `pyproject.toml`,
  `package.json` (`react` or `expo`), `build.gradle.kts`, `Package.swift`
  or `*.xcodeproj`, `*.tf`; exactly one match is the stack, no question;
  more than one match or none: `tech-decision` for the stack (Steps); a
  repository with no stack is adopted without stack rules and the report
  says so.
- adopter and templates: `${CLAUDE_PLUGIN_ROOT}/bin/brg-adopt` and
  `${CLAUDE_PLUGIN_ROOT}/templates/repo/`; both ship with the plugin.
  If the plugin root is unset, stop: "install Bearing (`bash install.sh`)
  and rerun".
- Makefile: the repository's own; if absent, the adopter offers the
  stack's template; if still absent after step 5, the report names the
  stack's native test command as the gate until one exists.
- lead and group for CODEOWNERS: `--lead`, `--group` of the adopter; if
  absent, the placeholders `@lead` and `@engineering`, listed under Not
  done.

## Steps

**Decisions first, only for what detection cannot answer.** The stack is
detected (Inputs), not decided: when exactly one marker matches, use it
and say so. Run `tech-decision` for the stack only when detection finds more
than one match or none and the engineer wants a stack; then options, a
recommendation with reasons, one question, the engineer decides, and the
ADR records it. Nothing else here is a decision.

1. Resolve the repository and the working tree as in Inputs.
2. Resolve the stack as in Inputs. Pass it so the stack rules file and,
   when the repo has no Makefile or CI, the stack templates are offered.
3. Run `bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-adopt" --stack <id> [--dir .]`
   (omit `--stack` when there is none). Read the summary: `added N, kept
   K, conflicts C`.
4. For each conflict, show a short `diff` between the existing file and its
   `.bearing-new`, and recommend one of: take ours (the standard), keep theirs,
   or merge (for CLAUDE.md: keep their snapshot and rules, take the
   `@AGENTS.md` first line and the skills table; for `.gitignore`: append;
   for Makefile: add the missing targets, never replace theirs).
5. Apply only what the engineer chose. Remove the `.bearing-new` files that were
   resolved; list any left.
6. `bash .githooks/install.sh` (inside a git repository), unless the
   adopter reported `conflict  core.hooksPath is <dir>`: then do not run
   it (it would overwrite that value); show the two fixes it printed
   (chain `.githooks/<hook>` from each hook in `<dir>`, or set
   `core.hooksPath` by hand) and let the engineer choose. Then `make -n
   check` to prove the gate exists; when it does not, say which native
   command stands in until the Makefile is added. Suggest `doctor`
   for the machine-side check.
7. Report in the four headings (Changed, Verified, Not done, Noticed),
   with the counts, and the commit command for the engineer.

## Output contract

```
## Adopt: <repo> (stack <id> | no stack)
Tree: clean | dirty (<N> files, listed under Noticed)
brg-adopt: added N, kept K, conflicts C
Conflicts resolved: R (ours O, theirs T, merged M); left as .bearing-new: L
Hooks: installed (core.hooksPath=.githooks) | conflict (core.hooksPath=<dir>, fix printed) | skipped (<reason>)
Gate: make -n check resolves | none (<native command> stands in)
Not done: CODEOWNERS handles, other stacks (--stack <id>), commit command
```

## Gotchas

- The single most common adoption fix is the first line of CLAUDE.md. It
  must be exactly `@AGENTS.md`; a markdown link does not import.
- Never delete the repository's own CLAUDE.md content. Their "things
  Claude gets wrong here" list is worth more than the template's.
- A repository with a Java Android app gets the `android` stack; the rules
  file covers the Java differences.
- `.claude/settings.local.json` is personal; never create or edit it here.
- An existing `core.hooksPath` (Husky's `.husky`) is never changed: the
  adopter counts it as a conflict and prints the chain lines. Setting it
  to `.githooks` silently turns the team's hooks off.
- A monorepo with several stacks is adopted once with the primary stack;
  the other stack rules are listed under Not done with the `--stack`
  value to rerun with.
