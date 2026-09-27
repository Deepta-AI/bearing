# payouts-service

Merchant payouts: fee calculation and bank settlement files. `make help`
lists the commands; `make check` is the gate.

## Coding agents

AGENTS.md is the standard for every agent. Claude Code reads it through
CLAUDE.md and is limited by `.claude/settings.json`. Codex settings for this
repository are in `.codex/config.toml`.

After cloning, run `make hooks` once so the push confirmation in
`.githooks/pre-push` is active.
