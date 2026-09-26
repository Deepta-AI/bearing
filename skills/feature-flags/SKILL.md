---
name: feature-flags
description: 'Adds, uses or removes a feature flag: default off, owner, removal date, one typed flags module, kill switch, tests for both states. Use when asked to "put this behind a flag", "add a feature flag" or "remove the flag".'
argument-hint: "add|use|remove <flag_name> [--owner <rotation>] [--task <ID>] [--kill-switch]"
allowed-tools: Read, Write, Edit, Grep, Glob, Skill, Bash(ls:*), Bash(make:*), Bash(git diff:*), Bash(git branch:*), Bash(date:*), Bash(go test:*), Bash(pnpm test:*), Bash(uv run pytest:*), Bash(./gradlew test:*), Bash(swift test:*), Bash(python3 *skills/feature-flags/scripts/flags_check.py*)
---

# feature-flags

A flag is a loan against the codebase. It is taken out with a name, an
owner and a date it is paid back. Every read goes through one module so
the loan can be found and closed.

## Inputs

- mode and flag name: `$ARGUMENTS`; if absent, ask one question.
- stack: detected from `go.mod`, `pyproject.toml`, `package.json` with
  `react` or `expo`, `build.gradle.kts`, `Package.swift` or
  `*.xcodeproj`; more than one match or none: ask one question.
- flags module: the stack path in step 1 when it exists; if absent,
  created from the shape below.
- register: `docs/operations/flags.md`; if absent, created from this
  skill's own `templates/flags.md`.
- removal task id: `--task`; if absent, the task id in the branch name;
  if absent, ask once; if none, the register row says `task: tbd` and
  the report lists it under Not done.
- owner: `--owner`; if absent, the first owner in CODEOWNERS; if absent,
  ask once for the rotation.
- value source: environment for services and web, remote config for
  mobile, as decided by an ADR or the Decisions first protocol below;
  if deferred, environment with a bundled default and say so.
- `.env.example`: created when absent.
- audit: `scripts/flags_check.py` in this skill, Python 3 only, run from
  the repository root; it reads the module, the register and the source
  tree, never the model's counts.
- gate: `make check` when the Makefile has a `check` target; if absent,
  the stack's native test command and the report says so.

## Steps

**Decisions first.** Before step 1, run `tech-decision` for the key
feature flags. `tech-decision` asks only about the keys this task needs that no
accepted ADR, the request or the code already settles, one question at
a time, and records only what the user decides; a key still
awaiting an answer follows
${CLAUDE_PLUGIN_ROOT}/skills/tech-decision/references/decision-protocol.md.

1. Resolve the stack as in Inputs. The flags module per stack:
   `internal/flags/flags.go`, `app/flags.py`, `src/lib/flags.ts` (web
   and RN), `domain/flags/Flags.kt`,
   `Packages/<Name>Kit/Sources/Core/Flags.swift`. Create it from the
   shape below if missing. Source of values: environment
   (`FLAG_<NAME>=true`) for services and web builds; remote config with
   a bundled default for mobile.
2. Read the register, creating it as in Inputs.
3. `add <flag_name>`: snake_case name, a typed constant in the module
   (`flags.NewCheckout`, `Flag.NEW_CHECKOUT`), default `false`, one
   line in the register with owner (a rotation, not a person), task id
   for the removal, target date (default 90 days from today:
   `date -v+90d +%F 2>/dev/null || date -d "+90 days" +%F`, the first form
   is macOS, the second GNU), and what "on" means. `--kill-switch`
   creates `kill_<path>` instead: on means the path returns its safe
   fallback; the register row says which fallback. Add `FLAG_<NAME>` to
   `.env.example` with the default.
4. `use <flag_name>`: the branch reads `flags.Enabled(ctx, flags.X)` or
   the stack's equivalent at the boundary (handler, screen, job), never
   deep inside a service. Write two tests, one per state, named for the
   flag. Grep for `os.Getenv("FLAG_`, `process.env.FLAG_`,
   `import.meta.env.VITE_FLAG_`, `BuildConfig.FLAG_` outside the module;
   every hit is a finding to route through the module.
5. `remove <flag_name>`: grep every read of the constant and the env
   name. Ask which branch survives (on, when the feature graduated; off,
   when it was abandoned) unless the register says. Delete the dead
   branch, the constant, the env line, the two state tests (keep one as
   the plain behaviour test), and set the register row to `removed
   <date>`. Run the gate.
6. Every mode ends with the audit:
   `python3 "${CLAUDE_PLUGIN_ROOT}/skills/feature-flags/scripts/flags_check.py"`
   (add `--module <path>` for a module outside the stack paths). It
   compares the register with the keys in the module, fails on a flag on
   one side only, a removed flag still in the module, a missing owner, a
   missing or past removal date, and every read of a flag key or a
   `FLAG_` variable outside the module; it fails when neither the module
   nor the register exists or no source file was scanned. Zero flags in
   both, with files scanned, is a valid pass and is reported as such. A
   past date is listed at the top of the report. Print the contract.

## Flags module shape

```
Names: one typed enumeration; a string literal flag name anywhere else is a finding.
Enabled(ctx, name) -> bool: reads the source once at start (services) or on refresh (mobile),
  returns the bundled default when the source has no value, logs at debug on first read.
Override for tests: WithFlags(ctx, map) or a fake FlagSource injected in DI.
No network call inside Enabled; mobile refreshes remote config in the background.
```

## Output contract

```
## Feature flag: <mode> <flag_name> (<stack>)
Module: <path>; register: docs/operations/flags.md
| Flag | Default | Owner | Removal task | Target date | Reads |
| ... | off | <rotation> | <ID or tbd> | <date> | N |
<flags_check.py "feature-flags:" counts line, verbatim>
Findings: <each flags_check.py problem: line>
Tests: <file> (on, off)
gate: make check | <native command>: passed | failed (<target>)
```

A count the script did not print is not written. The table's Reads
column is informational (reads through the module, from Grep); the
gate is the script's line.

## Gotchas

- Default off means off everywhere, including qa. Turn it on per
  environment through the source, never by editing the default.
- A flag without a removal date is a permanent configuration setting;
  say so and move it to config instead of the register.
- A kill switch is checked at the top of the risky path with no other
  logic, so the fallback works even when the path itself is broken.
- Mobile flags ship inside the bundle as defaults; the remote value can
  only widen, never protect what the bundled default already exposes.
- Two flags that must agree are one flag. Nested flags are a finding.
- A flag past its target date is listed at the top of the audit even
  when it was not the flag asked about.
- A `tbd` removal task is itself a finding on the next audit; it does
  not disappear because nobody named a ticket.
