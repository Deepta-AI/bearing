---
name: docs-drift
description: 'Finds docs that no longer match the code (broken links and paths, gone make targets, unused env vars, stale pages) and fixes the stale side. Use when asked "are the docs up to date", "check the README" or "docs drift".'
argument-hint: "[--root <dir>] [--strict] [--exclude <glob>]... [--stale-after N] [--report-only]"
allowed-tools: Read, Edit, Grep, Glob, Skill, Bash(git log:*), Bash(git diff:*), Bash(git merge-base:*), Bash(python3 *skills/docs-drift/scripts/docs_drift.py*)
---

# docs-drift

Docs drift when code changes by hand, in another harness, or in a branch
nobody documented. The script finds every claim a machine can check; the
judgement is which side is true. Code is the truth for what the system
does. The doc is the truth for what was intended. A doc behind the code
is updated; code that left an intended design is a finding for the
engineer, never a quiet rewrite of the doc.

Run it when inheriting a codebase (after `onboard-repo`), after a stretch of
work outside this kit, and before `definition-of-done` passes a branch that touched
code a doc names.

Not this: `openapi-spec check` owns spec against routes;
`prose-lint` owns wording; `traceability` owns requirement links.

## Inputs

- Root: `--root`, else the repository root (the working directory).
- Finder: `scripts/docs_drift.py` in this skill, Python 3 only. It reads
  every `*.md` in the repository (CONTRIBUTING.md and a service's own
  README included; minus `docs/archive/`, test fixtures, vendored and
  build folders, `--exclude` globs), checks each doc's `make` claims
  against the nearest Makefile above it, and prints `path:line: kind: detail` lines and one summary line.
  Kinds that fail: `broken-link`, `broken-path`, `broken-make`. Warnings:
  `env-unused`, `stale`, `make-unverified`, and `history` (a broken claim
  inside `docs/adr/`, `docs/decisions/`, `docs/postmortems/`,
  `docs/incidents/` or a CHANGELOG); `--strict` fails on warnings too.
- Staleness threshold: `--stale-after N` commits touching referenced code
  after the doc's own last commit; default 5. Skipped outside git.
- Opt-outs the finder honours: `<!-- docs-drift: ignore -->` on or above a
  line, `<!-- docs-drift: ignore-file -->` in a doc. Added only for a
  claim about another repository or a generated target layout, with the
  reason in the same comment.
- Mode: `--report-only` edits nothing; otherwise docs this skill owns are
  edited (the table in step 4).
- The change, when the request names one ("my branch", "this MR", "the
  rename"): the base is the merge base with the default branch;
  `git diff --find-renames --name-status <base>...HEAD` and
  `git diff <base>...HEAD` list what moved, including what the user did
  not mention.
- History for a path: `git log --oneline -5 -- <path>` and, for a missing
  path, `git log --oneline --diff-filter=DR --name-status -3 -- <path>`
  to find where it went.

## Steps

1. When the request names a change, read its diff first (Inputs) and list
   every old name it retired or value it changed: paths, make targets,
   flags, env vars, defaults, output text. Grep each old name across the
   whole repository, every file type, not only markdown: CI config,
   compose files, scripts that call scripts, `--help` text and comments
   carry the same claims, and the finder reads markdown only. A hit in
   a doc is a finding for step 4. A hit in CI or other config (a job
   still calling the removed script) breaks the build: it goes first
   under Not done with the line, even though it is not a doc.
2. Run `python3 "${CLAUDE_PLUGIN_ROOT}/skills/docs-drift/scripts/docs_drift.py" --root <root> --json`
   with `--strict`, `--exclude` and `--stale-after` passed through
   (`--report-only` is this skill's, not the script's). Print its
   summary line verbatim as Before. Zero
   docs found: stop non-zero with "0 docs found, nothing checked"; that
   is a repository with no docs to drift, not a pass.
3. For each finding, read the doc line and the code it names. For a
   missing path or target, run the history commands under Inputs: a
   rename or a move gives the new name; a deletion gives the commit. For
   `stale`, run `git log --oneline <doc commit>..HEAD -- <paths>` from
   the detail and read what those commits changed against what the doc
   says. A stale warning whose statements all still hold is closed with
   no edit and counted as checked.
   Then read, line by line, every doc this skill owns and every doc the
   request names, whether or not the finder flagged it: the finder checks
   names, not behaviour, and stale warnings need history a fresh clone
   lacks. Check each claim about what happens against the code that makes
   it happen: a setup step against what reads it (a `.env` the docs say
   to copy but nothing loads), a target's described effect against its
   recipe and what it runs over (`make test` "runs the unit tests" with no
   test files passes on nothing), a claim about CI or another external
   gate against config in the repository, a design's stated behaviour
   (ordering, validation, status codes) against the handler, and a
   postmortem or ADR action marked done against the code that should
   carry it. Each is a finding, routed like the finder's in step 4.
   Three claim types fail most often, and a reader only catches them by
   computing the answer:
   - Numbers and defaults (a row count, a limit, a timeout, a port, the
     expected output line). The value is what the documented invocation
     produces, so trace it through every layer that can set it: flag,
     environment, Makefile `?=` or `export`, compose or CI env, then the
     code default; check units (`64 << 10` is 64 KiB, not 1 MB). A
     Makefile default overrides the script's own default for anyone
     following a `make` step. Where it is safe, run the documented
     command against scratch state (point the data path at a temp file)
     and compare its real output with the doc's.
   - Examples (a request body, a config snippet, a CLI call). Check each
     field against what parses it: struct tags or schema, name matching
     (Go's decoder matches field names case-insensitively and silently
     drops unknown keys), required fields, and what the handler actually
     writes back (status, body, headers). An example the code accepts
     but ignores is wrong even though it "works".
   - Copies. The same claim usually sits in several docs; grep for it and
     fix or report every copy. Where two docs disagree, the code decides
     which is right; fixing only the flagged one leaves a contradiction.
4. Decide which side is true, then route by owner:

   | Doc | Owner | On drift |
   | --- | --- | --- |
   | `api/openapi.yaml` and docs quoting it | `openapi-spec` | `check` mode |
   | `docs/architecture/` | `architecture-diagram` | a revision |
   | `docs/runbooks/` | `runbook` | a revision |
   | `docs/design/` HLD, LLD | `high-level-design`, `low-level-design` | a revision |
   | `docs/adr/` | `adr` | never rewritten; a superseding ADR when the decision changed |
   | `docs/postmortems/`, CHANGELOG entries | history | never fixed; listed under Noticed |
   | README, CONTRIBUTING, AGENTS.md, CLAUDE.md, other markdown | this skill | edited here |

   - Code is true (a rename, a moved file, a removed target, a variable
     renamed in config): the doc is behind. Edit the line when this skill
     owns the doc; otherwise invoke the owner with the finding.
   - Doc is true (a design, ADR or PRD says X and the code does Y, or a
     path the design requires was never built): the code drifted. Nothing
     is edited; it is a finding for the engineer with the doc line and
     the code line.
   - Unclear (no history, no design says either way): ask one question
     naming both sides, or under `--report-only` list it as undecided.
5. Edits are the smallest change that makes the claim true again: the
   new path, the target that replaced the old one, the variable the code
   reads. A claim that is no longer true of anything is removed with the
   sentence that depends on it, not left as a dead reference. Edit only
   the lines that drifted; sections that still hold are not reworded.
   A doc marked generated (a header, a docs target, a generator
   script) is regenerated with its generator and the diff read, never
   hand-edited.
6. Rerun the command from step 2; print its summary line as After. A
   broken finding still present that step 4 did not route to the engineer
   or an owner is a failure of this run, not a pass.
7. Print the contract.

## Output contract

```
## Docs drift: <root> (<N> docs)
Before: <docs-drift summary line, verbatim>
After: <docs-drift summary line, verbatim> | not rerun (--report-only)

### Changed
- <doc>:<line>: <old claim> -> <new claim> (code is true: <commit or file>)
- handed to <skill>: <doc> (<K> findings)

### Verified
- <K> stale warnings read against their commits and still true: <docs>

### Not done
- still calls the old name (not a doc): <file>:<line>: <old> (gone in <commit>)
- code drifted from design: <doc>:<line> says <X>; <file>:<line> does <Y>
- undecided: <doc>:<line> (<question asked or pending>)

### Noticed
- history not edited: <adr or postmortem>:<line>: <finding>
- opt-out added: <doc>:<line> (<reason>) | none
```

A count the script did not print is not written; a section with nothing
in it says none.

## Gotchas

- A green run means every checkable claim holds, not that the docs are
  right. Prose about behaviour ("retries three times", "loads `.env`",
  "runs the unit tests") is outside the finder; the read in step 3 is
  what catches it, and a stale warning only says where to read first.
- A history doc is never edited, but its claims about the present are
  still checked: a postmortem action marked done that the code lacks is
  a regression for the engineer, listed under Not done with both lines.
- A "Last reviewed" or "Last verified" date moves only when the whole doc
  was checked end to end, including running its commands; fixing three
  lines is not a review.
- Editing the doc to match code that violates an ADR hides the violation
  and makes the next reader trust the wrong design. Doc is true there.
- An ADR or postmortem naming a path that later moved is correct for its
  date. Fixing it rewrites history; list it and move on.
- A gitignored path (`.env`, build output) is never flagged; a path
  created at runtime and not ignored will be. Add it to the ignore file
  if it is generated, or the opt-out comment if the doc describes another
  repository's layout.
- `env-unused` also fires on a name the doc spells wrong; check the code
  for a near miss before deleting the line.
