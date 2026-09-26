---
name: secrets
description: 'Handles secrets without seeing values: inventory, rotation, leak response (revoke, rotate, scrub, audit), gitleaks, .env.example parity. Use when "a key was committed", "rotate the secret" or "secret leaked".'
argument-hint: "inventory | rotate <name> | leaked <name> [--commit sha] | scan | parity"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(ls:*), Bash(mkdir -p:*), Bash(chmod +x:*), Bash(gitleaks:*), Bash(git ls-files:*), Bash(git log:*), Bash(git status:*), Bash(git diff:*), Bash(date -u:*), Bash(scripts/env-parity.sh:*), Bash(python3 *skills/secrets/scripts/ci-credentials.py*)
---

# secrets

A secret's value never enters the conversation. This skill works on
names, places, owners and dates; the values stay in the manager and
the engineer types them where they go.

Not this: `vapt-report` reports a found secret as a finding; this skill
is what happens next. `git-hooks` installs the hook that calls
the scan.

## Inputs

- Mode: `$1`; if absent, `inventory`.
- Code reads of environment: grep for `os.Getenv(`, `os.LookupEnv(`,
  `envconfig` tags, `os.environ[`, `os.getenv(`, pydantic `Settings`
  fields, `process.env.`, `import.meta.env.`, `System.getenv(`,
  `ProcessInfo.processInfo.environment[`; zero hits is a stop for
  `parity` and a note for `inventory`.
- Example file: `.env.example`; if absent, created by `parity` with
  every name found and empty values, and the report says so.
- Manager: `docs/security/SECRETS.md` `Manager:` line, else the CI
  variables page, a `.sops.yaml`, `vault` or cloud secret references in
  the infra code; none: "manager: unknown" and one question.
- Scanner: `gitleaks` on `PATH` with `templates/gitleaks.toml` copied to
  `.gitleaks.toml`; not installed: `scan` prints the install line and
  the pre-commit hook line and exits non-zero, nothing is claimed clean.
- Rotation procedures: `references/rotation.md` in this skill.
- Templates: `templates/SECRETS.md`, `templates/leak-record.md` (to
  `docs/security/leaks/<YYYY-MM-DD>-<name>.md`), `templates/env-parity.sh`
  (installed to `scripts/env-parity.sh`).

## Steps

1. `inventory`: list every secret by name from the env reads, the CI
   file, compose files and infra variables marked sensitive. Print
   "secrets: N named". N=0: stop with "0 secrets found; nothing to
   inventory". Fill `docs/security/SECRETS.md`: name, type (from
   `references/rotation.md`), where used (`path:line`), owner, rotation
   period, last rotated (`unknown` when unknown, never a guess), how
   it is injected. Every `unknown` is a row in Not done.
2. `rotate <name>`: read the row and the procedure for its type. Print
   the steps for the engineer: create the new value in the manager,
   deploy with both accepted (dual-read) where the type allows, cut over,
   revoke the old, verify with the check the procedure names. The agent
   runs none of them. On the engineer's "done", set `last rotated` to
   today (`date -u +%F`).
3. `leaked <name> [--commit sha]`, in this order, no step skipped:
   - Revoke now at the provider; the procedure names where. Ask for
     confirmation before continuing; a leaked secret is live until then.
   - Rotate as in step 2; every service that reads it redeploys.
   - Scrub: print the history-rewrite command from
     `references/rotation.md` for the path or the replace-text file,
     and the force-push and re-clone notice for every collaborator.
     The engineer runs the rewrite; the agent never rewrites history
     or pushes.
   - Audit blast radius: `git log --all --oneline -- <path>` for how long
     it was in history; which remotes, forks, CI logs, artefacts and
     chat messages carried it; what the secret could reach. Count
     "exposed: N commits, M places".
   - Notify: the owner, security contact from `SECURITY.md`, and the
     provider when their policy asks; a customer note when data was
     reachable.
   Record all of it in `docs/security/leaks/<date>-<name>.md` from the
   template with UTC times.
4. `scan`: copy `templates/gitleaks.toml` to `.gitleaks.toml` when
   absent, then `gitleaks git --config .gitleaks.toml --no-banner
   --redact .` for history and `gitleaks dir --config .gitleaks.toml
   --redact .` for the tree. Print "scan: N commits, M files, F
   findings". F>0 goes to step 3 per finding. Then the CI files, which
   gitleaks misses when the value is not credential-shaped
   (`DEPLOY_TOKEN: q8Zr4L`):
   `python3 "${CLAUDE_PLUGIN_ROOT}/skills/secrets/scripts/ci-credentials.py" --root .`
   It reads every GitLab, GitHub, CircleCI, Bitbucket, Azure, Drone,
   Travis and Jenkins file and fails on a credential-named key with a
   literal value, a `--password` or `--token` flag given a literal, a
   URL with a password in it, or a credential-shaped string. A value
   read from the CI's secret store (`${{ secrets.X }}`, `$VAR`) passes;
   a throwaway service container's default password (`postgres`,
   `guest`) is counted, not a finding. It prints file, line and key,
   never the value. Each finding is a secret in history: step 3, then
   the value moves to a masked, protected CI variable. Zero CI files
   exits 1 and the report says "no CI files", not clean. Add `gitleaks protect
   --staged --redact` to the pre-commit hook when `.githooks/pre-commit`
   exists and lacks it.
5. `parity`: install `templates/env-parity.sh` as `scripts/env-parity.sh`
   and run it. It prints "env vars: N read in code, M in .env.example,
   K missing, U unused" and exits non-zero when N=0 or K>0. Add the
   missing names to `.env.example` with empty values and a comment;
   never a value. Add `make env-check` when a Makefile exists.
6. Print the contract for the mode.

## Output contract

```
## Secrets: <mode>
Inventory: N secrets, unknown last-rotated U, owners missing O  (docs/security/SECRETS.md)
Rotate <name>: <type>, steps printed N, last rotated <date> | awaiting engineer
Leaked <name>: revoked <HH:MMZ> | pending; rotated; scrub command printed; exposed N commits, M places; notified <list>
Scan: N commits, M files, F findings   Hook: <installed | already present | no hook dir>
CI: <ci-credentials.py count line, verbatim> | no CI files
Parity: N read, M in example, K missing, U unused   Makefile: env-check <added | present | none>
Record: docs/security/leaks/<file> | n/a
```

## Gotchas

- Never print, echo, cat or grep a value. `--redact` on every scan;
  `.env` itself is never opened, only `.env.example`.
- Revoke before rotate. A rotated key that was not revoked is two live
  keys, one of them public.
- A history rewrite does not reach forks, clones, CI caches or the
  provider's crawler. Treat the value as burned forever; the rewrite
  only stops the next reader.
- `.env.example` with real-looking placeholders (`sk_live_...`) trips
  the scanner and teaches people to paste. Empty values, one comment.
- A secret with no owner rotates never. Empty owner cells are the first
  Not done line.
- Rotation without dual-read is an outage; the procedure says which
  types support it (most tokens do, some webhooks do not).
