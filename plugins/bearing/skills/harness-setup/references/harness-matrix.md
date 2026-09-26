# Harness matrix

Verified against the official documentation on 22 September 2026. When a
harness changes its format, update the generator (`bin/brg-harness`) and
this table together. "Guard" means the shared `bin/brg-guard` logic runs
inside that harness's own hook; without it, the git pre-push hook
(terminal confirmation) and CI still hold the push rule.

| Harness | Skills folder | Instructions file | Path-scoped rules | Hook that blocks a shell command | Command policy | Subagents |
| --- | --- | --- | --- | --- | --- | --- |
| Claude Code | `~/.claude/skills`, `.claude/skills`, plugins | CLAUDE.md importing AGENTS.md | `.claude/rules/*.md` with `paths:` | PreToolUse, exit 2 (plugin hooks, guard) | settings.json allow/ask/deny | `.claude/agents/*.md` |
| Cursor | `.cursor/skills`, `.agents/skills`, `~/.cursor/skills` | AGENTS.md natively; `.cursor/rules/*.mdc` | `.mdc` with `globs:` | `beforeShellExecution` in `.cursor/hooks.json`, deny JSON (guard) | none documented (hook is the block) | `.cursor/agents/*.md` |
| Codex CLI | `.agents/skills`, `~/.agents/skills` | AGENTS.md natively (32 KiB cap) | directory nesting only | `PreToolUse` in `.codex/hooks.json`, exit 2 (guard) | `.codex/rules/*.rules` execpolicy (forbidden), `approval_policy` in config.toml | `.codex/agents/*.toml` |
| Gemini CLI | `.gemini/skills`, `.agents/skills`, `~/.gemini/skills` | GEMINI.md with `@./AGENTS.md` import; AGENTS.md via `context.fileName` | none (imports only) | `BeforeTool` in `.gemini/settings.json`, `{"decision":"deny"}` (guard) | `tools.exclude` `run_shell_command(git push)` | `.gemini/agents/*.md` |
| GitHub Copilot | `.github/skills`, `.agents/skills`, `~/.copilot/skills` | `.github/copilot-instructions.md`; AGENTS.md natively | `.github/instructions/*.instructions.md` with `applyTo` | `preToolUse` in `.github/hooks/*.json`, deny JSON (guard); VS Code reads the same files | CLI `--deny-tool 'shell(git push)'`; VS Code `chat.tools.terminal.autoApprove` | `.github/agents/*.agent.md` |
| OpenCode | `.opencode/skills`, `.agents/skills`, `~/.config/opencode/skills` | AGENTS.md natively; `opencode.json` instructions list | none | JS plugin `tool.execute.before` throwing (guard) | `opencode.json` permission.bash allow/ask/deny | `.opencode/agents/*.md` |
| Windsurf (Devin Desktop) | `.devin/skills`, `.agents/skills` | AGENTS.md natively; `.devin/rules/*.md` | `trigger: glob` with `globs:` | `pre_run_command` in `.devin/hooks.json`, exit 2 (guard) | allow and deny lists in the settings UI only | Devin Local only |
| Cline | `.cline/skills`, `.clinerules/skills` | `.clinerules/*.md`; AGENTS.md | `paths:` frontmatter | `.clinerules/hooks/PreToolUse` executable, `{"cancel":true}` (guard; parameter key not verified) | none (model-set approval) | model-spawned only |
| Zed | `.agents/skills`, `~/.agents/skills` | `.rules` or AGENTS.md (first match) | none | not supported (settings only, no adapters by design) | `.zed/settings.json` tool_permissions always_deny regex | built-in subagent tool |
| Kiro | `.kiro/skills`, `~/.kiro/skills` | `.kiro/steering/*.md`; AGENTS.md | `inclusion: fileMatch` | `PreToolUse` in `.kiro/hooks/*.json`, exit 2 (guard) | `permissions.yaml` (user level) | `.kiro/agents/` |

## What every harness gets from the repository alone

- AGENTS.md: the standard.
- Makefile and CI: the gate.
- `.githooks/`: commit shape, formatting and secret checks on staged files;
  push refused unless a person types the branch name on the terminal
  (`BEARING_PUSH_CONFIRMED=1` for CI).
- `.bearing/state/`: session handoff files, harness-neutral.
- `.bearing/bin/brg-guard`: the vendored guard the adapters call.

## What stays Claude-only

Read-only reviewer subagents with tool limits, and the settings.json
permission model. The limit is the tool list, not a hook: Claude Code
ignores the `hooks`, `mcpServers` and `permissionMode` fields of an
agent loaded from a plugin, so `reviewer`, `verifier`,
`explorer`, `critic` and `security-auditor` get Read, Grep
and Glob only, and the calling skill writes the diff, log and file list
they need under `.scratch/` before it forks them. `test-writer`
keeps Bash to run tests; the plugin's session-level PreToolUse hook is
what screens its commands. Codex, Gemini, Copilot, OpenCode, Zed and Kiro have a
command policy the generator derives from `brg-guard --verbs` (prefix
matches, advisory); Cursor and Cline rely on the hook; Windsurf keeps its
lists in the UI. In every harness with a hook, the hook over the vendored
guard screens each shell command: it strips wrappers (`sudo`, `env`, `command`,
`exec`, `VAR=x`), git's `-C`, `-c`, `--git-dir` and `--work-tree`
options, and follows `eval`, `sh -c`, `xargs`, `npx`, `timeout`, `docker
exec` and command substitutions into the command they run.

The guard is defence in depth, not the wall. A pattern check over shell
text can be talked around, and a harness can skip a hook. The hard stops
are outside the agent: the git pre-push hook (a person types the branch
name on the terminal), protected branches on the remote, deploy jobs
that only a person can start, and, in Claude Code, the Bash sandbox the
repository settings template turns on.

## Gates beyond the shell guard

Three gates run over the same guard subcommands: `stop-gate` (a session
that changed files and has not passed `make check` since is sent back
once, never in a loop), `check-file` (the edited file is linted and the
problems go back to the agent) and `precompact` with `session --source
compact` (branch, changes, check state and the user's last requests
survive compaction).

| Harness | Stop gate | Edit check | Across compaction | Status |
| --- | --- | --- | --- | --- |
| Claude Code | Stop, `decision: block`, `stop_hook_active` | PostToolUse, `decision: block` | PreCompact, SessionStart `compact` | exercised live |
| Codex CLI | Stop, `decision: block`, `stop_hook_active` | PostToolUse on `apply_patch`, paths from the patch | PreCompact, SessionStart `compact` | from the docs; unverified |
| Cursor | stop, `followup_message`, `loop_count`, `loop_limit: 2` | postToolUse on Write, `additional_context` | none: preCompact output reaches only the user | from the docs; unverified |
| Others | none | none | none | the shell guard only |

## Fail closed

The adapters require `jq`. When the event JSON cannot be read (no `jq`,
invalid JSON, a missing or renamed command key, an empty command) the
adapter passes nothing or the sentinel `__BRG_UNPARSED__` to the guard,
and the guard denies with the reason "could not read the command;
refusing (fail closed)". A wrong key therefore never becomes a false
allow; it becomes a deny that names the cause, and the fix is the key in
the adapter.

## Unverified details

Codex's `tool_input` command key, Cline's parameter key and full event
list, OpenCode's bash args key. The adapters read the likely keys (and
the `cmd` variants) and deny when none is present, per the section above.
