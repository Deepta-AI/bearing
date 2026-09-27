---
name: feature-flags
description: 'Adds, uses or removes a feature flag: default off, owner, removal date, one typed flags module, kill switch, tests for both states. Use when asked to "put this behind a flag", "add a feature flag" or "remove the flag".'
argument-hint: "add|use|remove <flag_name> [--owner <rotation>] [--task <ID>] [--kill-switch]"
allowed-tools: Read, Write, Edit, Grep, Glob, Skill, Bash(ls:*), Bash(make:*), Bash(git diff:*), Bash(git log:*), Bash(git merge-base:*), Bash(git branch:*), Bash(date:*), Bash(go test:*), Bash(pnpm test:*), Bash(uv run pytest:*), Bash(./gradlew test:*), Bash(swift test:*), Bash(python3 *skills/feature-flags/scripts/flags_check.py*)
---

# feature-flags

A flag is a loan against the codebase. It is taken out with a name, an
owner and a date it is paid back. Every read goes through one module so
the loan can be found and closed.

The hard part is never the `if`. It is knowing every place the feature
reaches, what value each environment really resolves to, and whether a
change to the flag changes production. Most of this skill is those three
checks.

## Inputs

- mode and flag name: `$ARGUMENTS`; "merge it dark" or "put it behind a
  flag" is `add` then `use`; "rip it out" is `remove`.
- stack: from `go.mod`, `pyproject.toml`, `package.json` with `react` or
  `expo`, `build.gradle.kts`, `Package.swift` or `*.xcodeproj`.
- flags module: the stack path in step 2 when it exists, else created
  from the shape below.
- register: `docs/operations/flags.md` (or the path an ADR names). When
  it exists, its columns, headings and conventions are the team's: add
  or move one row in its own shape and never restructure it. When
  absent, create it from this skill's `templates/flags.md`.
- the team's rules: every ADR (list the directory; a later one may
  amend an earlier one) and README section on flags. Where it is
  stricter than this skill (a 60 or 90 day limit, a ticket format), it
  wins.
- removal task id: `--task`; else the ticket id in the branch name; else
  `tbd`, written as the plain word. Never write a placeholder that looks
  like a real id (`REP-TBD`, `REP-000`) and never invent a number.
- owner: `--owner`; else the rotation the register or ADR already uses
  for the owning team; else a team named in CODEOWNERS. A person is never
  the owner, even when CODEOWNERS lists one.
- base branch: `git merge-base HEAD origin/HEAD` (or `main`, `trunk`,
  `master`, whichever exists).
- audit: `scripts/flags_check.py` in this skill, run from the repository
  root.
- gate: `make check` when the Makefile has it, else the stack's native
  test command, and the report says which.

## Steps

**Decisions first.** When the value source is not settled by an ADR, the
request or the code, run `tech-decision` for it, following
${CLAUDE_PLUGIN_ROOT}/skills/tech-decision/references/decision-protocol.md
for a key still awaiting an answer. A repository that already has a
flags module has settled it.

1. **Audit before touching anything.** Run
   `python3 "${CLAUDE_PLUGIN_ROOT}/skills/feature-flags/scripts/flags_check.py"`
   (`--module <path>` for a module elsewhere). Keep its output: the
   `problem:` lines are the state you found, the `values:` lines show
   every `FLAG_` setting per file and line (and the deployed files that
   leave it unset), `config names:` lines are config files naming a flag
   (override maps, remote-config defaults), and `client read:` lines are
   the places the browser reads a flag by key. A `reads as ON` problem is
   the parser trap of step 2, already found.
2. **Read how a value becomes "on".** Open the module and answer, with
   the line: which sources feed it (environment, per-region files,
   per-account or per-tenant overrides, remote config), in what order,
   and how a string becomes a boolean. Test the parser against what the
   deploy config actually contains: `"false"`, `"0"`, `"off"` and `""`
   must be off. A parser that treats any non-empty value as on (Go
   `!= ""`, Python truthiness, JS `!!process.env.X`) turns every
   `FLAG_X=false` into on. That is a finding with a live consequence:
   name each deployed setting whose meaning is inverted and what is
   running in production today because of it. Fixing the parser changes
   production, so either fix it with a test for `"false"` and state which
   flags switch off in which environment on deploy, or leave it and
   recommend the fix; never fix it silently.
3. **Map the effective value everywhere.** List the environments from the
   deploy directory and manifests, not from the `values:` lines: a region
   or workload that never mentions the flag runs the default, and it is
   the one people forget. Include values that arrive indirectly: `envFrom`
   ConfigMaps and Secrets, shared env files, base images, Helm values (in
   Kubernetes an explicit `env` entry wins over `envFrom` for the same
   name). Then write the value each deployed environment and each
   overridden account resolves to, under the parser from step 2. Every
   separate process loads flags itself: a CronJob, worker or second binary
   has its own env list and its own `main`. Example and template files
   are not environments.

### add

4. **Check the name is free before using it.** Grep every config source
   from step 3 for `FLAG_<NAME>`: a shared ConfigMap or env file another
   team owns may already set it, and a workload that loads it turns the
   new flag on at merge (under a lenient parser even `off` does). Pick a
   name nothing sets, or override it to off in your own workloads; never
   edit another team's shared config to make room. Then: snake_case name, one typed constant in the module
   (`flags.CSVExport`, `Flag.NEW_CHECKOUT`), included wherever the module
   lists flags to load, default off. One register row in the register's
   own columns: owner rotation, removal task, target date, what "on"
   means for a user. Target date: the team's limit counted from today,
   inclusive, else 90 days:
   `date -v+90d +%F 2>/dev/null || date -d "+90 days" +%F`.
   `--kill-switch` creates `kill_<path>`: on means the path returns its
   safe fallback, named in the row. Add `FLAG_<NAME>` to `.env.example`
   with the off value. Add it nowhere else: every environment stays off
   by omission.

### use

5. **Find every exposure from the diff, not from one function.** Run
   `git diff <base>...HEAD` and list what this branch adds that a user,
   customer or another system can reach: routes, links or URLs to the
   feature inside other responses, emails and pages, attachments,
   notifications, jobs and other binaries, client payloads, public API
   specs. Grep the route path and the feature's user-visible strings as
   well as its entry function; a link to the new endpoint in an existing
   JSON response or email body is an exposure even though it never calls
   the new code.
6. **Gate only what is new.** Code that already ships on the base
   branch stays ungated, even when it calls the same function: a default
   off flag in front of it switches off live behaviour on merge. Leave
   the shared core (the builder, the serialiser) ungated; gate at each
   boundary.
7. **Gate first, before side effects.** With the flag off, the boundary
   returns before loading, auditing, metering, calling out or logging a
   business event, and answers as if the feature were never deployed
   (404 for a route, the field or link absent, no attachment), not 403.
8. Wire the flag into every process that exposes the feature: each
   binary loads the flags itself (`flags.FromEnv()` in its own `main`)
   and passes them in; a struct with a nil flag set must read as off.
9. Tests, named for the flag: each boundary in both states, including
   that off has no side effect and on is byte-for-byte the old
   behaviour. Keep existing tests for the feature by running them with
   the flag on; never delete them.
10. Grep for `os.Getenv("FLAG_`, `process.env.FLAG_`,
    `import.meta.env.VITE_FLAG_`, `BuildConfig.FLAG_`, `os.environ` with
    `FLAG_` outside the module: each hit is a finding. Routing it through
    the module is in scope only when the request asks for it or the
    change touches that code; otherwise report it with the line.
11. Report how to turn it on: the exact variable and every workload that
    must carry it (a Deployment and a CronJob are two places), so the
    first rollout does not light up half the feature.

### remove

12. **"At 100%" is a claim to verify.** From step 3, list every
    environment and account where the flag does not resolve to the
    surviving branch. For each, find why (the comment next to it, the
    ticket, the CHANGELOG) and whether that reason still holds. Apply the
    module's own rules when counting: an override the module ignores
    (expired, unknown account) affects nobody; one it honours does.
13. **A removal must be a no-op in production.** If any environment or
    account still resolves to the branch being deleted, merging the
    removal changes what they see. Do the removal on the branch, but the
    report opens with a blocker: who changes (region, account ids,
    count), why they were held, whether that reason still holds, and the
    safe order: flip them as their own change, observe, then merge the
    removal.
    An override that encodes a commitment (a contract, a regulator, a
    customer's written terms) is not rollout state, and no engineer's
    reading of the CHANGELOG releases it. Deleting the flag must not
    delete what those accounts are owed: either carry it into an explicit
    dated rule that is not a flag (a contract list with end dates, read by
    the feature, with a test for an account inside and past its date),
    keeping the old path for them only; or hold the merge until the
    commitment ends or its owner signs off. Say which, and name the
    owner.
14. Survivor: the register or the user says which branch survives (on
    when it graduated, off when abandoned); else the branch every
    production environment runs.
15. Delete the dead branch and the code only it used. Before deleting a
    file, grep its other importers: a shared helper moves or stays. Then
    delete the constant, every read including string-keyed client reads
    (`client read:` lines, the client serialisation such as
    `for_client` or `window.FLAGS`, templates), the `FLAG_` line and the
    comment about it in every env file and manifest, entries in override
    maps (keep the other flags' entries), the off-state test (keep one
    plain behaviour test), and any docs describing the toggle.
    Cached clients still read the key after the server stops sending it:
    a script or bundle cached by browsers or a CDN (unversioned URL, long
    `max-age`) takes the off branch until it expires, and an installed
    mobile build does forever. Change the asset URL (version or
    fingerprint) in the same change, or keep sending the key as a
    constant on for one cache lifetime with a dated note to drop it; for
    mobile, until the versions that read it are unsupported.
    Keep public signatures unless the flag parameter becomes dead; update
    every caller when one changes.
16. Register: move the row to Removed with the date and the surviving
    branch, in the register's own shape. A CHANGELOG line names any
    behaviour change from step 13.

### every mode

17. Run the gate, then the audit again. Every `problem:` line is fixed
    or reported with its reason; pre-existing problems (an overdue flag,
    a direct read) are raised even when they were not the flag asked
    about. A removed flag must leave no `sets removed flag` or `reads
    removed flag` line. Nothing is committed.

## Flags module shape

```
Names: one typed enumeration; a string literal flag name anywhere else is a finding.
Parse: "true"/"1"/"on" are on; everything else, including "false" and "", is off.
Enabled(ctx, name) -> bool: reads the source once at start (services) or on refresh (mobile),
  returns the bundled default when the source has no value.
Override for tests: WithFlags(ctx, map) or a fake FlagSource injected in DI.
No network call inside Enabled; mobile refreshes remote config in the background.
```

## Output contract

```
## Feature flag: <mode> <flag_name> (<stack>)
Blockers: <who changes on merge and why, or none>
Exposure: <each boundary gated, file:line> | not gated: <shared or pre-existing code, why>
Effective values: <env or account = on|off, per the parser>
Register: <the row as written>
<flags_check.py "feature-flags:" counts line, verbatim>
Findings: <parser, direct reads, overdue flags, stale config, each with file:line>
Tests: <file> (on, off)
Turn on: <variable and every workload that must carry it>
gate: make check | <native command>: passed | failed (<target>)
```

A count the script did not print is not written.

## Gotchas

- Default off means off everywhere, including qa. Turn it on per
  environment through the source, never by editing the default.
- A flag without a removal date is configuration; say so and move it.
- A kill switch is checked at the top of the risky path with no other
  logic, so the fallback works even when the path itself is broken.
- Mobile flags ship inside the bundle as defaults; the remote value can
  only widen, never protect what the bundled default already exposes.
- Two flags that must agree are one flag. Nested flags are a finding.
- A comment in a manifest saying a flag "stays off" is a claim; the
  parser decides.
- Flags serialised into a page are read by string key in the client, so
  a compiler never finds them; the audit's `client read:` lines do.
