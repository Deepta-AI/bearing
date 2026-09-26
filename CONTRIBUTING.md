# Contributing to Bearing

## Forking without diverging

1. Fork the kit and set `BEARING_KIT_REMOTE` in `~/.config/bearing/bearing.env`
   to your fork's git URL; `install.sh`, `brg-scaffold` and `brg-adopt`
   read it, so every developer installs from the fork and every
   repository's settings point at it.
2. Fill in `NOTICE.md`. Nothing else in the kit names a company.
3. Keep company-specific skills in a separate plugin, or give their names
   a prefix of your own, so upstream merges stay clean. A fork that adds
   unprefixed skills under `skills/` must accept merge conflicts when
   upstream adds a skill of the same name.
4. Pull upstream with `git pull upstream main`, run `make check`, and
   bump `VERSION` with a CHANGELOG entry before rolling out.

## Adding or changing a skill

- `new-skill <name>` scaffolds the directory with the required
  sections. The lint (`make lint-skills`) enforces: a directory name of lowercase
  words joined by hyphens, at most 64 characters, `name` equal to the
  directory, a description of at most 220 characters that
  says "Use when" with at least two quoted phrases, the sections Inputs,
  Steps, Output contract and Gotchas (stack skills use their own set),
  every backticked `templates/` or `references/` path existing, no "the
  company", no `RS-` literal, and `Skill` in `allowed-tools` for any
  skill that runs the decision protocol.
- `make lint-tools` checks that every command a skill's Inputs, Steps or
  Commands section tells the agent to run is granted by its
  `allowed-tools`. A command the skill only prints for the engineer (an
  install line, a target it adds) goes in `bin/lint-skill-tools.allow`
  with its reason; commands the guard blocks (push, tag, publish) are
  exempt on their own.
- A skill works on its own: every input names a fallback. Never make a
  skill depend on another skill having run.
- A skill never pushes, merges, tags, deploys or opens an MR. It prints
  the command for the engineer.
- Prefer a genuinely better third-party skill as the main choice for a
  stage; record it in `bin/gen-guide.py` (`ALTERNATES`, `STAGES`) so the
  handbook and `docs/WORKFLOW.md` regenerate.

## Testing a change

- `make check` is the gate: plugin validation (strict), skill lint, JSON,
  shellcheck, prose, version match, docs freshness and `tests/run.sh`.
- `make test` alone runs the suite: the guard deny table, hook fixtures
  through every harness adapter, scaffold of every stack, adopt
  idempotency, tracker adapters against fake servers, deterministic docs.
- `make lint-evals` requires `evals/<name>/evals.json` in
  skill-creator's schema for every skill not on `evals/.pending`
  (the skills that predate the rule; the list only shrinks). Write and
  run the cases with Anthropic's `skill-creator`, which compares the skill
  against a no-skill baseline and tunes an auto skill's description;
  `new-skill` step 7 hands a new skill to it. Its workspace goes
  under `.scratch/skill-evals/`, which git ignores.
- Reinstall locally with `claude plugin uninstall bearing@bearing && claude
  plugin install bearing@bearing` and try the skill in a scaffolded repo.

## Releasing

1. Collapse `[Unreleased]` in `CHANGELOG.md` into the new version.
2. Update `VERSION`; `make lint-version` checks `plugin.json` and
   `marketplace.json` match.
3. `make docs` and commit the regenerated `docs/`.
4. A person tags and pushes: `git tag -a vX.Y.Z -m "bearing X.Y.Z" && git
   push origin main --tags`.
5. Developers upgrade with `upgrade-tools`.

## Style

- No em dashes in prose, commits, docs or comments. Rewrite the sentence.
- No AI attribution lines in commits or MRs.
- Conventional Commits with the task id when there is one.
- Scripts run on macOS bash 3.2 and Linux; shellcheck clean.
