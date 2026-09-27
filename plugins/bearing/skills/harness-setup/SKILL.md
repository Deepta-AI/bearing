---
name: harness-setup
description: 'Sets up a repository for another coding agent (Cursor, Codex, Gemini CLI, Copilot, OpenCode, Windsurf, Cline, Zed, Kiro): rules, hooks, skills. Use when asked to "set up Cursor" or "use this with Codex".'
argument-hint: "<cursor|codex|gemini|copilot|opencode|windsurf|cline|zed|kiro|all> [--no-skills]"
allowed-tools: Read, Grep, Glob, Edit, Write, Bash(bash *bin/brg-harness *), Bash(python3 *scripts/harness_check.py *), Bash(ls:*), Bash(git remote:*), Bash(git status:*), Bash(git diff:*), Bash(git check-ignore:*), Bash(git config --get:*), Bash(git ls-files:*), Bash(chmod +x:*), Bash(make -n:*), Bash(make check:*), Bash(wc:*), Bash(diff:*)
---

# harness-setup

"The same guardrails as Claude Code" means this repository's own
`.claude/settings.json`, rules and git hooks, not a generic list. The kit's
generator (`bin/brg-harness`) writes each harness's thin adapters over the
vendored `brg-guard`, whose table blocks push, merge, publish, deploy and
destructive verbs. It does not read the repository's settings, look at what
other harness files already say, or check that git will run the hooks. Those
three gaps are where a setup that looks complete lets `make deploy` through,
ships a hooks file `.gitignore` drops, or leaves a stale rule telling the
agent to push. This skill closes them.

## Inputs

- Harness name: from `$1`; if absent, ask one question listing the ids.
- The repository: the current git repository.
- The kit's git URL for skill installation: `git -C <kit> remote get-url
  origin`; if absent, or the network is not available, use `--no-skills`
  and print the install command for the user.
- `references/harness-matrix.md`: what each harness supports and loses;
  read it before promising a feature.

## Steps

1. **Audit before writing.** From the repository root run
   `python3 "${CLAUDE_PLUGIN_ROOT}/skills/harness-setup/scripts/harness_check.py" audit <harness>`.
   It lists the Claude settings (deny, ask, Read denies), make targets whose
   recipe, prerequisite or `$(MAKE)` call reaches a deploy verb, every
   AGENTS.md and AGENTS.override.md with its size, instruction and
   config files other harnesses already read, the git hooks with their
   worktree and index modes and `core.hooksPath`, and which files the
   generator will write that `.gitignore` would drop. Each FINDING is work
   for step 4; FINDING lines are keyword hits, so read every file it lists
   in full (a legacy `.cursorrules` can contradict the Go rules without
   saying push).
2. **Generate.** Run `bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-harness" <harness> [--no-skills]`.
   It prints written, kept and conflict counts; a conflict is a file that
   already existed with other content, the proposal beside it as
   `<file>.bearing-new`. Walk each with `diff`, merge (keep the user's own
   entries, add ours), delete the resolved `.bearing-new`, and rerun until
   it reads `N harness(es) checked, N wired`.
3. **Carry the repository's own denies.** Run
   `harness_check.py extend <harness>`: it writes
   `.bearing/settings-denies.txt` from `.claude/settings.json` (plus any
   make target that hides a deploy verb), a second shell hook over it, and
   registers the hook (Cursor and Codex automatically; for others it says
   where). Then `harness_check.py check <harness>` feeds the harness's own
   event JSON to every configured shell hook: each settings deny in bare,
   `bash -lc`, `VAR=1` and `-C <dir>` forms, each ask, `cat` of each
   Read-denied path, ordinary work (`git status`, `make check`, tests) and
   two unreadable events. It must end `0 gap(s)`. A rerun of brg-harness
   now shows the hooks config as a conflict: keep the extended version.
4. **Resolve every audit finding** in the repository, smallest change that
   makes it true, then run the audit again:
   - A rule file that contradicts AGENTS.md (an always-applied `.mdc`
     telling the agent to push or edit applied migrations, a nested
     AGENTS.md granting push or deploy on some branch): rewrite the
     offending lines to agree with the root AGENTS.md, keep the rest, and
     name the file and the conflict in the report. A nested AGENTS.md is
     read after the root, so it wins for files under it; Codex reads an
     `AGENTS.override.md` instead of the AGENTS.md beside it.
   - Root AGENTS.md over 32 KiB (Codex's default `project_doc_max_bytes`;
     the rest is silently dropped): move the ground rules (push, deploy,
     merge) near the top, or move bulk reference material (tables, code
     lists) into a linked file with its content intact. Check with
     `wc -c` and the byte offset of the rules. Raising the limit in project
     config is a fallback: it fixes Codex only.
   - A committed `.codex/config.toml` with `approval_policy = "never"`,
     `sandbox_mode = "danger-full-access"`, `network_access = true` or
     `inherit = "all"`: set `sandbox_mode = "workspace-write"`,
     `approval_policy = "on-request"`, network off, `inherit = "core"`.
     A trusted project applies this file to whoever opens it.
   - Generated files `.gitignore` drops: add a narrow re-include
     (`!.cursor/hooks.json`) and confirm with `git check-ignore -v` that
     nothing the hooks config runs is still ignored.
   - A git hook that is not executable: git skips it silently. `chmod +x`
     fixes this clone; other clones get it only when the mode is committed
     (index mode in `git ls-files -s`), so say so. With
     `core.hooksPath` unset the hooks run nowhere until each clone sets it
     (the repository's hooks target, make hooks here); say so.
   - A git hook bypassed by an environment variable
     (`LEDGER_PUSH_CONFIRMED=1`): an agent can set it, so the git hook is a
     wall against people, not agents. The harness hook carries the rule.
5. **Carry the rules.** `.claude/rules/*.md` with `paths:` become scoped
   rules where the harness has them (Cursor `globs:`, Copilot `applyTo`);
   read each converted file and check the globs and body survived. Where the
   harness reads AGENTS.md natively (Codex, Cursor, Gemini CLI, Copilot,
   OpenCode) say that the pointer file is a courtesy.
6. **Verify and report.** `make check` passes. Leave the changes
   uncommitted for review (Claude's settings usually ask before a commit).
   Report in the shape below.

## Testing discipline

- Test a hook by piping event JSON into it, never by running the command it
  should block. To see what a make target would run, `make -n <target>`.
- If a script must be exercised end to end, put a fake binary of each
  deploy tool (`kubectl`, `helm`, `terraform`) first on PATH in a scratch
  folder and set HOME to a folder there. A `[ -r /dev/tty ]` test is true
  without a controlling terminal, so a prompt guard can fall through to the
  real tool.
- Never edit a deploy target, a manifest or application code to make a
  guard work: the hook is where the refusal belongs, and a changed deploy
  recipe is a change to how a person releases.
- Never edit a user-level config (`~/.codex/config.toml`, `~/.cursor`,
  `~/.kiro/permissions.yaml`); write the project file and print the lines
  the user adds.

## Output contract

```
harness: <name>
files: <W> written, <K> kept, <C> conflicts (resolved: <how>)
denies: <N> from .claude/settings.json, check: <M> commands, <G> gaps
fixed: <each audit finding and what changed, or reported only and why>
holds here: harness hook (verified by event JSON | format unverified), git hooks (<active | inactive until make hooks>), CI
does not carry over: <Claude-only items, e.g. read-only subagents, Read() denies beyond the shell hook>
each person must: <make hooks, trust the project, install jq, user-level lines>
not exercised: <real <harness> session, skill install if skipped>
```

## Gotchas

- The adapters and the settings hook need `jq` and fail closed without it:
  every shell command is refused with a reason. Say so; teammates need jq.
- Codex reads `.codex/` (hooks, rules, config) only in a trusted project;
  the contractor trusts it once. Execpolicy prefix rules miss wrapped
  forms (`bash -lc`, `git -C`); the hooks carry those.
- Claude's `ask` has no hook equivalent outside Cursor (`permission: ask`);
  elsewhere the settings hook refuses it. Say which it became.
- `Read(./.env)` denies Claude's Read tool. The shell hook refuses commands
  that name the file; Cursor also has `.cursorignore`. Neither stops a
  program that opens it itself.
- Hook formats change between releases; if a harness renames its command
  key every shell command is refused with "could not read the command".
  Fix the key, never loosen the guard. Harnesses on the `unverified:` line
  have been checked against recorded fixtures only: ask the user to try one
  blocked command (`git push --dry-run`) in the real tool.
- A Zed setup has no hooks by design: the settings deny list and the git
  pre-push confirmation are the enforcement.
