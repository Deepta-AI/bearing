# bearing

The required plugin of the Bearing marketplace: a development workflow for
teams that build software with coding agents.

## What it contains

- `skills/`: 94 workflow skills, one per job from the brief to the
  runbook (PRD, backlog, architecture, design, test cases, review, merge
  request, release, runbooks and the rest), each callable as
  `/bearing:<name>`.
- `agents/`: 8 subagents (reviewer, verifier, security auditor,
  explorer, test writer, doc writer, critic, PRD drafter).
- `hooks/`: `hooks.json` and 6 hook scripts over one guard,
  `bin/brg-guard`, which refuses publishing and history-rewriting
  commands and runs the format and check gates.
- `bin/`: the `brg-` scripts the skills and hooks call (guard, doctor,
  scaffold, adopt, tracker adapters, harness setup, pack installer) and
  `pinned-packs.txt`, the one file that pins every external fetch.
- `templates/`: the repository files every repository on the standard
  commits, and the user env file `templates/user/bearing.env`.

## Install

Inside Claude Code:

```
/plugin marketplace add Deepta-AI/bearing
/plugin install bearing@bearing
```

This plugin is required. The stack plugins are optional:
`bearing-backend` (Go, Python, Node, data pipelines, infrastructure) and
`bearing-apps` (React, Next.js, React Native, Flutter, iOS, Android).

## More

Documentation, the installer and the source: <https://github.com/Deepta-AI/bearing>.
Licence: MIT (see `LICENSE`).
