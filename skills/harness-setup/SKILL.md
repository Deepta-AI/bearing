---
name: harness-setup
description: 'Sets up a repository for another coding agent (Cursor, Codex, Gemini CLI, Copilot, OpenCode, Windsurf, Cline, Zed, Kiro): rules, hooks, skills. Use when asked to "set up Cursor" or "use this with Codex".'
argument-hint: "<cursor|codex|gemini|copilot|opencode|windsurf|cline|zed|kiro|all> [--no-skills]"
allowed-tools: Read, Grep, Glob, Bash(bash *bin/brg-harness *), Bash(ls:*), Bash(git remote:*), Bash(git status:*), Bash(diff:*)
---

# harness-setup

The standard is harness-neutral by construction: AGENTS.md is the canon,
the Makefile is the gate, the git hooks enforce commit shape, formatting
and the rule that a person pushes, and `bin/brg-guard` holds the guard
logic that Claude Code's hooks call. This skill adds each other harness's
thin adapters over those pieces and installs the skills where that
harness reads them.

## Inputs

- Harness name: from `$1`; if absent, ask one question listing the ids.
- The repository: the current git repository; if it has no `.claude/rules/`
  the Cursor conversion writes only the always-on rule and says so.
- The kit's git URL for skill installation: `git -C <kit> remote get-url
  origin`; if absent, pass `--kit-url`, or skip with `--no-skills` and
  print the command.
- `references/harness-matrix.md`: what each harness supports and what is
  lost; read it before promising a feature.

## Steps

1. Run `bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-harness" <harness> [--no-skills]`
   from the repository root. It prints written, kept and conflict counts;
   a conflict means a file already existed with different content and the
   proposal sits beside it as `<file>.bearing-new`. The `adapters:` line counts
   a harness as wired only when its config file references every adapter
   and nothing is left as `.bearing-new`; any harness not wired exits 1, so a
   conflicted hooks config is never reported as full wiring.
2. Walk any conflicts with the user (`diff`), apply what they choose,
   remove the `.bearing-new` files that were resolved, and run step 1 again
   until the summary reads `N harness(es) checked, N wired`.
3. Read `references/harness-matrix.md` and tell the user, for the chosen
   harness, which guard rails now hold (git hooks and CI always; harness
   hooks where supported), which are still Claude-only (read-only
   subagents, the permission deny list), and the equivalent in that
   harness when one exists (approval policies, allow and deny lists).
4. If the harness is on the `unverified:` line (Copilot, Kiro, Windsurf,
   Codex, Cline, OpenCode), say so plainly: its hook format has been
   checked against recorded fixtures only, not the real tool, so ask the
   user to ask that harness for one blocked command (a push with
   `--dry-run`) and confirm the hook denies it. Cursor and Gemini CLI have been
   exercised for real.
5. If skills were installed, print the harness's skills folder and one
   phrase to try (`workflow`). If the harness reads AGENTS.md
   natively (Codex, Cursor, Gemini CLI, Copilot, OpenCode), say that the
   pointer file is a courtesy and AGENTS.md is what it reads.
6. Report in the fixed shape with the counts.

## Output contract

```
harness: <name>
files: <W> written, <K> kept, <C> conflicts
skills: installed to <path> | skipped (command printed)
wired: <N> of <N> harnesses (<not wired: reason>)
holds here: git hooks, CI, <harness hooks: yes|no|yes, format unverified>
claude-only: subagents, permission deny list
```

## Gotchas

- Hooks differ per harness and change between releases; the matrix
  records what was verified and when. When a harness has no hook
  facility (Zed: settings only, no adapters by design), the git pre-push
  confirmation is the enforcement, and it works because agents have no
  terminal to type the branch name into.
- The adapters fail closed: they need `jq`, and a command they cannot
  read (bad JSON, missing key, no `jq`) is denied with a reason, never
  allowed. If a harness renames its command key, the symptom is every
  shell command denied with "could not read the command"; fix the key in
  the adapter, do not loosen the guard.
- Copilot's `toolArgs` arrives as an object in the hooks docs and may
  arrive as a JSON string from Copilot CLI; `read-json.sh` decodes a JSON
  string on the way down, so both shapes work and a non-JSON string is
  denied.
- The Cursor conversion keeps the globs from `paths:`; a rule with no
  `paths:` becomes an always-on rule, which costs tokens every turn.
- Never edit a harness's user-level config (`~/.codex/config.toml`,
  `~/.cursor`) from here; write the project-level file and print the
  merge instructions.
