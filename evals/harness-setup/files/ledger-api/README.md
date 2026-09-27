# ledger-api

Double-entry ledger service. `make help` lists the commands; `make check`
is the gate.

## Coding agents

The standard for every agent is AGENTS.md. Claude Code reads it through
CLAUDE.md, with path rules in `.claude/rules/` and the permission settings
in `.claude/settings.json`. Cursor users: shared rules live in
`.cursor/rules/`; keep personal Cursor settings out of git.

After cloning, run `make hooks` once. To release, a person runs `make ship`
(the gate, then `make deploy`).
