# Contributing to Bearing

## Adding a skill

1. Pick the plugin. Workflow skills that work in any stack go in
   `plugins/bearing`. A skill about one language or framework goes in its
   family plugin (`plugins/bearing-backend` or `plugins/bearing-apps`);
   see ADR-0002.
2. Name it: lowercase words joined by hyphens, unique across all three
   plugins, saying what it does. The folder name and the frontmatter
   `name` are the same.
3. `SKILL.md` has frontmatter (`name`, `description`, `allowed-tools`, and
   `argument-hint` when it takes arguments) and the sections Inputs,
   Steps, Output contract and Gotchas. The description is at most 220
   characters, says what the skill does and then "Use when" with at least
   two quoted phrases a user would type. Keep it under 140 lines.
4. `allowed-tools` grants only what the skill runs. Never a bare `Bash`,
   and never `Bash(bash:*)`, `Bash(sh:*)` or `Bash(python3:*)`; name the
   script. A script a skill runs lives in its plugin's `bin/` and is
   referenced as `${CLAUDE_PLUGIN_ROOT}/bin/<script>`.
5. Every script gets a unittest under `tests/` (`make test`).
6. Every check (a script, a lint, a gate) fails on empty input and prints
   the count of things it examined. A check that examined zero items did
   not pass.
7. Evals: `evals/<name>/evals.json` with realistic cases for the new
   skill, and three trigger requests plus two near misses in
   `evals/triggers.json`. `evals/.pending` lists skills that predate the
   evals rule; it only shrinks. Never add a new skill to it.
8. `make docs` regenerates the table in `docs/SKILLS.md` from the
   frontmatter; do not edit the table by hand. Add a line under
   Unreleased in `CHANGELOG.md`.
9. `make check` passes.

## Rules every skill follows

- No team-specific facts in a skill: no hostnames, chat channels, ticket
  prefixes, team names or company names. The adopting repository supplies
  them (its `CLAUDE.md` or `.bearing/company.json`); the skill says where
  it looks and what it does when they are absent.
- A skill never pushes, merges, tags or deploys (ADR-0001).
- A mention of a skill in another plugin carries that plugin's prefix, for
  example `bearing:release` from a stack skill.
