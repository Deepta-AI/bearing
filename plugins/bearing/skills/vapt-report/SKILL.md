---
name: vapt-report
description: 'Writes the VAPT security report for a release from scanner findings, linked to the threat model, with a ship or block decision. Use when asked for a "VAPT report", "security sign-off" or "pentest report".'
argument-hint: "<version or tag> [scope notes] [--allow-stale]"
allowed-tools: Read, Write, Grep, Glob, Skill, Agent, Bash(git diff:*), Bash(git log:*), Bash(git tag -l:*), Bash(git ls-files:*), Bash(git show:*), Bash(git rev-parse:*), Bash(git rev-list:*), Bash(ls:*), Bash(mkdir -p docs/security), Bash(mkdir -p .scratch), Bash(mkdir -p .scratch/vapt/*), Bash(python3 *skills/vapt-report/scripts/collect_findings.py*)
---

# vapt-report

A release ships with a written security position or it does not ship.
The scanners find; this skill writes the position. claude-security (a
researcher per component, three verifiers per finding, a vote counted
outside the model) and gstack `/cso` (fifteen phases, an independent
verifier per finding, a confidence gate) out-find anything a single
read-only pass can do, so they run first and this skill turns their
findings into the report, the threat-model links and the release
decision.

Not this: `threat-model` designs mitigations before the code;
`secrets` handles a leaked secret; this skill signs off a release.

## Inputs

- Version: `$1`; if absent, the latest tag from `git tag -l --sort=-v:refname`;
  no tags, `HEAD` with the whole codebase in scope, named as such.
- Range: the previous tag to the version; no previous tag or not a git
  repository, the whole codebase, said so in the report.
- Scanner reports, read by
  `python3 "${CLAUDE_PLUGIN_ROOT}/skills/vapt-report/scripts/collect_findings.py"`:
  the newest `CLAUDE-SECURITY-*/CLAUDE-SECURITY-RESULTS.jsonl` with its
  revision stamp, and the newest `.gstack/security-reports/*.json` from
  `/cso`. If neither exists, the skill asks which to run (step 2).
- Threat model: `docs/security/threat-model-*.md`; if absent, the report
  says "no threat model" and recommends `threat-model`.
- Scope list (services, URLs, apps): looks in the CLAUDE.md snapshot and
  `$2`; if absent, from the code (entrypoints, Dockerfiles, compose files,
  route registrations) and listed as "scope derived from code".
- Security checklist: `SECURITY.md`; if absent, the scanners' own
  coverage stands in and the report names it.
- Attribution: `.bearing/company.json`; if absent, the author line and
  delivering entity read "unattributed", never a guessed company
  (`company-attribution` fills it later).
- Template: `docs/templates/VAPT.md` when present, else `templates/VAPT.md`
  in this skill's folder.

## Steps

1. Resolve the version, range and scope as in Inputs. Resolve the
   release commit (`git rev-parse <version>`) and the time of the oldest
   commit in the range (`git log -1 --format=%cI <previous tag>`, or none
   for the whole codebase).
2. Collect the findings:
   `python3 "${CLAUDE_PLUGIN_ROOT}/skills/vapt-report/scripts/collect_findings.py" --commit <release sha> --since <range start> --out .scratch/vapt-findings.json`
   - "0 scanner reports found": ask once which scanner to run. claude-security
     is the deeper one (unattended, multi-agent, heavy on tokens); the user
     types `/claude-security` and picks "scan changes" for the range or
     "scan the codebase" for a first release, since it cannot be started
     from a skill. `/cso` is faster and interactive; on the user's yes,
     invoke the `cso` skill (Skill tool) with `--diff` for a range or
     `--comprehensive` for a first release. Then rerun the collector.
   - Stale (a scan of another commit, or a `/cso` report older than the
     range): say which, and rerun the scanner. Only on the user's
     explicit yes, rerun the collector with `--allow-stale`; the report's
     Method section then names the scanned commit.
   - Neither scanner installed: the fallback agents have Read, Grep and
     Glob and no shell, so collect the scope first:
     `mkdir -p .scratch/vapt/<version>`, then for a range
     `git diff --output=.scratch/vapt/<version>/diff.patch <range>`,
     `git diff --stat --output=.scratch/vapt/<version>/stat.txt <range>`,
     `git diff --name-only --output=.scratch/vapt/<version>/files.txt <range>`
     and `git log --format='%h %s' --output=.scratch/vapt/<version>/log.txt <range>`;
     for the whole codebase only the file list, as a diff from the empty
     tree: `git diff --name-only --output=.scratch/vapt/<version>/files.txt 4b825dc642cb6eb9a060e54bf8d69288fbee4904 <release sha>`.
     Then fork `security-auditor` (Agent tool) with those paths, then
     one `verifier` per Critical and High (all in one message, each
     with its finding and the diff path), and treat REFUTED as dropped. The Method section says
     "fallback: single read-only auditor, no scanner", and the release
     decision cannot be "cleared" on it alone; the best it reaches is
     "cleared, pending a scanner run".
   Then insecure defaults, whatever source ran above: when the
   `insecure-defaults:audit` skill is installed, load it through the
   Skill tool with the scope `.`, since a fallback secret in a config
   file the range did not touch still ships in this release. It sweeps
   six categories (fallback secrets, default credentials, fail-open
   switches, weak crypto, permissive access, debug leakage) and has a
   refuting verifier trace each candidate to the security decision it
   reaches, and to whether the deployment manifests supply the value.
   It finds; this skill still writes the report and the decision, and
   the Method section names it as a source with its scope. Its confirmed
   findings go in the findings table with source `insecure-defaults`
   and its severity (CRITICAL is Critical, and so on); one at a file
   and line the collector already has is named as a second source on
   that row, not listed twice. Its counts go on their own line, never
   added to the collector's. Status `no-candidates` is "0 candidates",
   not "clean"; `report-failed` is read from its `findings` and
   `coverage`; any other status, or the skill not installed, is
   "insecure defaults: not run (<status or reason>)".
3. Link the threat model. For each threat row in
   `docs/security/threat-model-*.md`: a finding in the threat's component
   or at its mitigation's `file:line` means the mitigation failed; cite
   the threat id on that finding. A threat marked `planned` with no
   mitigation in the range is listed as open risk. Count the threats
   read, the threats linked to a finding and the planned ones still open.
4. Fill the template as `docs/security/VAPT-<version>.md`
   (`mkdir -p docs/security`): scope with the release commit, method
   (each source with its report path, scanned commit or date and
   verification status, exactly as the collector printed), the findings
   table from `.scratch/vapt-findings.json` (severity, area, title,
   reproduction, fix, sources, threat id, an owner and task id
   placeholder on every Critical and High), checked-none-found from the
   checklist, the threat-model section, and the release decision.
5. Print the contract. Release is blocked while any Critical or High is
   open, from the collector or from the insecure-defaults pass.

## Output contract

```
## VAPT: <version> (<range | whole codebase>) at <sha12>
vapt-findings: <the collector's counts line, verbatim>
Threat model: T threats read, L linked to findings, P planned still open | none
Findings: Critical C, High H, Medium M, Low L   Checked, none found: K
Insecure defaults: N confirmed (Critical c, High h, Medium m, Low l; S also in scanner rows), R refuted | 0 candidates | not run (<status or reason>)
Attribution: <entity> | unattributed
Release: cleared | blocked (<n> Critical/High open) | cleared, pending a scanner run
File: docs/security/VAPT-<version>.md
```

## Gotchas

- Counts come from the collector's line. A severity count the collector
  did not print is not written; the insecure-defaults counts come from
  its own report and stay on their own line.
- A stale scan is a scan of other code. Accepting one is the user's
  call, recorded in the report, never a default.
- Never mark a finding fixed in the report unless the fix commit is in the
  range.
- Reproduction steps must be runnable by a person without the conversation;
  a curl, a screen path, a request body.
- No secrets, tokens or real PII in the report, even redacted-looking ones;
  a secret finding names the file and line and the secret type only.
- claude-security writes its report directory with a `.gitignore` of `*`;
  the VAPT file under `docs/security/` is the record that is committed.
