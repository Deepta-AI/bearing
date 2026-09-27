# Bearing

A Claude Code plugin marketplace that gives any repository the same
development workflow. Three plugins move in lockstep (see VERSION):

| Plugin | Holds | Install |
|---|---|---|
| `bearing` | workflow skills that work in any stack (ADRs, releases, runbooks) | required |
| `bearing-backend` | stack conventions for Go and Python services | optional |
| `bearing-apps` | stack conventions for mobile and web apps | optional |

The skill list is in [docs/SKILLS.md](docs/SKILLS.md). To add or change a
skill, read [CONTRIBUTING.md](CONTRIBUTING.md) first.

```
make check   # every gate this repository has
make docs    # regenerate the skill table in docs/SKILLS.md
```

Bearing is used by many teams. Anything specific to one team (hosts,
chat channels, ticket prefixes, deploy commands) lives in that team's
repository, in `CLAUDE.md` or `.bearing/company.json`, never in a skill.
