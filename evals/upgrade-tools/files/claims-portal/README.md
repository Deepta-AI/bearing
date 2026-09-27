# claims-portal

Triage service for incoming insurance claims. Python 3, standard library only.

## Working here

```
make check      # tooling check + unit tests
make bootstrap  # clone the agent tooling at the versions in .claude/tooling.lock
```

## Agent tooling

Claude Code tooling for this repository is pinned in `.claude/tooling.lock` and
cloned by `make bootstrap` from the internal mirror in `.mirror/` (the build
hosts have no internet; the platform team's mirror-sync job refreshes `.mirror/`
every night). See docs/adr/0002-vendored-agent-tooling.md.

| Tool | Version | Where |
|------|---------|-------|
| team kit (team-review plugin) | 0.8.1 | tools/team-kit |
| gstack | 1.2.0 | .claude/skills/gstack |
| ui-polish skill pack | 2.1.0 | .claude/skills/ui-polish |

Our own skills (for example `.claude/skills/incident-notes`) live in this
repository and are not part of the lock.

After pulling a change to the lock, run `make bootstrap` and restart Claude Code.
