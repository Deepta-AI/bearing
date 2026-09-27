---
name: vapt-report
description: 'Writes the VAPT security report for a release from scanner findings, linked to the threat model, with a ship or block decision. Use when asked for a "VAPT report", "security sign-off" or "pentest report".'
argument-hint: "<version or tag> [scope notes] [--allow-stale]"
allowed-tools: Read, Write, Grep, Glob, Skill, Agent, Bash(git diff:*), Bash(git log:*), Bash(git tag -l:*), Bash(git ls-files:*), Bash(git show:*), Bash(git rev-parse:*), Bash(git rev-list:*), Bash(git status:*), Bash(git merge-base:*), Bash(git grep:*), Bash(git archive:*), Bash(tar -x:*), Bash(ls:*), Bash(mkdir -p docs/security), Bash(mkdir -p .scratch), Bash(mkdir -p .scratch/vapt/*), Bash(python3 *skills/vapt-report/scripts/collect_findings.py*)
---

# vapt-report

A release ships with a written security position or it does not ship.
The scanners find; this skill decides what their output means for one
commit and writes that down. claude-security (a researcher per component,
three verifiers per finding) and gstack `/cso` (fifteen phases, a verifier
per finding) out-find a single read-only pass, so they run first. What they
do not do, and what goes wrong when a report is transcribed from them: they
scan a scope (often only the diff) at a moment (often not the release
commit), they report one bug at several lines, they have false positives,
and they never check the working tree, the tag, the CHANGELOG or the
deployment manifests. This skill does.

Not this: `threat-model` designs mitigations before the code;
`secrets` handles a leaked secret; this skill signs off a release.

## Inputs

- Version: `$1`; if absent, the latest tag from `git tag -l --sort=-v:refname`;
  no tags, `HEAD` with the whole codebase in scope, named as such.
- Range: the previous tag to the version; no previous tag or not a git
  repository, the whole codebase, said so in the report.
- Scanner reports, read by the collector (step 2): the newest
  `CLAUDE-SECURITY-*/CLAUDE-SECURITY-RESULTS.jsonl` with its revision stamp,
  and the newest `.gstack/security-reports/*.json` from `/cso`.
- Threat model: `docs/security/threat-model-*.md`; if absent, the report
  says "no threat model" and recommends `threat-model`.
- Scope list (services, URLs, apps): the CLAUDE.md snapshot and `$2`; else
  from the code (entrypoints, Dockerfiles, manifests, route registrations),
  listed as "scope derived from code".
- Security checklist: `SECURITY.md`; if absent, the sources' own coverage
  stands in and the report names it.
- Attribution: `.bearing/company.json`; if absent, "unattributed", never a
  guessed company.
- Template: `docs/templates/VAPT.md` when present, else `templates/VAPT.md`
  in this skill's folder.

## Steps

1. Pin the release. `git rev-parse <version>^{commit}` is the release
   commit; `git log -1 --format=%cI <sha>` its time; the range start is the
   previous tag's commit time. Then `git status --porcelain` and
   `git diff --stat <sha>`: when the working tree is not the release commit
   (main ahead of the tag, uncommitted edits), every judgement is about the
   release commit. Read files with `git show <sha>:<path>`; for agents that
   only have Read, export the tree once:
   `mkdir -p .scratch/vapt/<version>/tree` then
   `git archive <sha> | tar -x -C .scratch/vapt/<version>/tree` and give them
   that path. A fix that exists only in the working tree or on a later
   commit is not in this release; say so where it matters.
2. Collect the scanner findings:
   `python3 "${CLAUDE_PLUGIN_ROOT}/skills/vapt-report/scripts/collect_findings.py" --commit <sha> --commit-time <release commit time> --since <range start> --out .scratch/vapt-findings.json`
   It prints a counts line, a `coverage:` line per source, any
   `problem:` (stale, unreadable) and any `check: possible duplicate`.
   - No report: ask once which scanner to run. claude-security is the
     deeper one; the user types `/claude-security` ("scan changes" for a
     range, "scan the codebase" for a first release), since a skill cannot
     start it. `/cso` is faster: on a yes, invoke the `cso` skill with
     `--diff` for a range or `--comprehensive` for a first release, then
     rerun the collector. Nobody to ask: go to the fallback below.
   - Stale (claude-security scanned another commit; a `/cso` report is older
     than the release commit): a stale scan is evidence about other code.
     Tell the user which commit or date it covered and offer a rerun;
     `--allow-stale` only on their explicit yes, named in Method. Nobody to
     ask, or no rerun before the deadline: do not accept it; review the
     range yourself (fallback below) and re-check every stale finding
     against the release commit: fixed (the fix commit is in the range and
     the flaw is gone, step 4), still open, or in a file unchanged since the
     scanned commit (`git diff --quiet <scanned> <sha> -- <file>`), where
     the finding stands on the scan's own evidence.
   - Fallback (no scanner installed, or the stale path): collect the range
     `mkdir -p .scratch/vapt/<version>` then
     `git diff --output=.scratch/vapt/<version>/diff.patch <range>` and
     `git log --format='%h %cI %s' --output=.scratch/vapt/<version>/log.txt <range>`
     (whole codebase: `git ls-files` at the exported tree). Read the diff
     yourself, then fork `security-auditor` (Agent tool) with the diff and
     the exported tree path, and one `verifier` per Critical and High (all
     in one message); REFUTED is dropped. Method says "fallback: read-only
     review, no scanner at <sha>"; the best decision it reaches is "cleared,
     pending a scanner run".
3. Look where the scanners did not. A diff-scoped scan (`coverage:
   changes`, `/cso diff`) never saw code the range did not touch, yet a
   fallback secret in an unchanged config loader ships in every release.
   When `insecure-defaults:audit` is installed, load it (Skill tool) with
   scope `.`; its confirmed findings join the table with source
   `insecure-defaults`, its counts on their own line; `no-candidates` is
   "0 candidates", not "clean". Not installed: do the sweep yourself at the
   release commit:
   - every secret, signing key, credential or auth switch read from the
     environment with a literal fallback or no emptiness check
     (`git grep -nE 'Getenv|os\.environ|process\.env' <sha>`), traced to the
     deployment manifests: if no manifest sets it, production runs on the
     fallback, which is a finding at the reach of that secret (a forgeable
     session is Critical), not a note;
   - credentials in manifests, ConfigMaps and `.env` files at the release
     commit, and when each entered history (`git log -S<distinctive prefix> --format=%h`),
     because a committed key needs rotation, not only moving;
   - routes registered without the auth wrapper their siblings use, and
     docs (README route tables, SECURITY.md) that claim otherwise.
4. Triage every row. This is the job; a table copied from the scanners is
   not a position.
   - Confirm each Critical and High, and anything else that decides the
     release, in the release commit's code: quote the line that makes it
     true. A scanner's "verified" is a vote at its scanned commit, not
     proof at this one. A row the code refutes goes under "Refuted" with
     the quoted line and is not counted.
   - Merge by root cause, not by line: one missing check is reported at the
     route, the handler and the sink. Resolve every `check: possible
     duplicate`; a merged row names every source.
   - Fixed means both: the fix commit is an ancestor of the release commit
     (`git merge-base --is-ancestor <fix> <sha>`) and the flaw is gone at
     `<sha>`. Read the fix; partial fixes are common (a prefix check that
     misses control characters or encodings, one handler fixed and its
     sibling not). A CHANGELOG line or a closed ticket is a claim, not
     evidence; when it is false for this release, say so.
   - Severity by reach at this commit: unauthenticated, cross-tenant,
     production configuration. A finding you confirmed yourself counts
     exactly like a scanner's. "Suspected, to be confirmed" is not a status
     a release decision can rest on: confirm or refute it now, and if you
     cannot, it is open and counts.
5. Link the threat model. A confirmed finding in a threat's component or at
   its mitigation's `file:line` means that mitigation does not hold; cite
   the threat id and say what the threat model claims versus the code. A
   `planned` threat with no mitigation at the release commit is open risk.
   Count threats read, linked and planned-still-open.
6. Write `docs/security/VAPT-<version>.md` (`mkdir -p docs/security`) from
   the template: scope with the release commit; Method with each source,
   its report path, scanned commit or date, coverage and verification, and
   the collector's counts line verbatim as provenance; the findings table
   (reproduction a person can run without this conversation, fix at a
   file:line, sources, threat id, owner and task placeholders on every
   Critical and High, status); Refuted; checked-none-found (only items
   someone actually examined); threat model; what was not done (no dynamic
   test of a running service unless one was run); the decision. The
   report's own totals are after triage and show the arithmetic: scanner
   rows, minus merged, minus refuted, plus found outside the scanners.
7. Decide and print the contract. Blocked while any Critical or High is
   open, whatever found it. Sign-off, approver and reviewer stay blank for
   a named person; never fill them. A fix that landed after the tag ships
   in a new version cut from a commit containing it (say v1.4.1); never
   propose moving a published tag.

## Output contract

```
## VAPT: <version> (<range | whole codebase>) at <sha12>
vapt-findings: <the collector's counts line, verbatim> | fallback review
Coverage: <each source: changes since <base> | codebase | stale, not accepted>
Findings after triage: Critical C, High H, Medium M, Low L (R rows, -D merged, -F refuted, +A found outside the scanners)
Threat model: T threats read, L linked to findings, P planned still open | none
Insecure defaults: N confirmed | 0 candidates | swept by hand | not run (<reason>)
Release: cleared | blocked (<n> Critical/High open: <ids>) | cleared, pending a scanner run
File: docs/security/VAPT-<version>.md
```

## Gotchas

- No secret value anywhere you write: report, final message, or a scratch
  file inside the repository. That includes a hard-coded fallback secret
  (name the file, line and kind, never the literal) and scanner
  reproductions that quote a key. The collector writes a `.gitignore` of
  `*` beside its output; keep every other scratch file under `.scratch/`.
- Nothing but the report changes: no fixes, no commits, no tags; the
  scanner folders and any uncommitted edits you found stay as they were.
- claude-security writes its report folder with a `.gitignore` of `*`; the
  file under `docs/security/` is the record that gets committed.
