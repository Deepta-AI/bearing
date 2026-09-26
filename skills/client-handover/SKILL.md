---
name: client-handover
description: 'Writes the client handover pack at the end of an engagement: environments, access list, deploy, runbooks, debt, licences, sign-off. Use when asked to "prepare the handover" or "hand this over to the client".'
argument-hint: "<client name> [delivering entity, default: the one in .bearing/company.json]"
context: fork
agent: doc-writer
allowed-tools: Read, Write, Grep, Glob
---

# client-handover

The pack is what the client's next team works from when nobody from the
engagement is on the call. Every line is either sourced from the
repository or marked unconfirmed, so the client knows what to verify.

Not this: `session-handoff` saves session state for the next session on a
branch; this is the pack a client's next team works from.

## Inputs

- Client name: looks in `$1`; if absent, asks one question; never taken
  from the repository name. Nothing after that stops the skill.
- Delivering entity: looks in `$2`, else `.bearing/company.json`; if absent,
  writes "unattributed" and continues; `company-attribution init` fills it later.
- This skill runs forked under `doc-writer`, which has no shell: git
  facts come from `.git/HEAD` (branch), `.git/config` (remotes),
  `.git/packed-refs` and `.git/refs/tags/` (tags, the last one is the
  delivered version); Makefile targets from the Makefile itself, read
  with Read and Grep (target lines and their recipes), never with a
  make dry run, which would need a shell. A fact that needs a command is
  written `unconfirmed:` with the command.
- Repository sources: the list in step 2; each missing one leaves its
  section `unconfirmed:`. Zero files at all: asks one question for the
  repository path or the documents; still nothing stops the skill:
  "provide the repository or its documents".
- Design, ADR, runbook and traceability docs: optional; a missing set is
  a known issue in section 8 with the skill that produces it.
- Template: `templates/HANDOVER.md` in this skill.

## Steps

1. Delivering entity from `$2`, else `.bearing/company.json`, else
   "unattributed". Client name from `$1`; missing: ask the one question
   under Inputs. Never guess the client from the repository name.
2. Gather in one batch and count the files read: README, the CLAUDE.md
   snapshot, `docs/design/*.md` (HLD, LLD, diagrams), `docs/adr/*.md`,
   `docs/runbooks/*.md`, `docs/postmortems/*.md`, `docs/traceability.md`,
   `docs/analytics/EVENT_SHEET.md`, `.env.example` (variable names only),
   `.gitlab-ci.yml`, the Makefile's build, test and deploy targets
   (Grep for `^[a-zA-Z_-]+:` and Read each recipe; an `include`d file is
   read too, and a target defined only in a file that is absent is
   `unconfirmed:`),
   infrastructure directories (`terraform/`, `deploy/`, `k8s/`,
   `docker-compose*.yml`), monitoring rules (`monitoring/`, alert
   YAML), dependency manifests (`package.json`, `go.mod`, `pyproject.toml`,
   `build.gradle*`, `Podfile`, `Package.swift`), and the git facts from
   the `.git/` files named under Inputs. Zero files read: return the one
   question under Inputs and stop.
3. Fill `templates/HANDOVER.md` section by section. Each section opens
   with `Source:` naming the file or command, or `unconfirmed:` naming
   what to ask and whom. Diagrams are referenced by path from the design
   docs, never redrawn. Environments list name, purpose, URL and who owns
   it; a URL not found in the repository is `unconfirmed:`.
4. Access inventory: one row per account, service user, key or role with
   its purpose and where the credential lives (secret manager path,
   vault, CI variable name). Values never appear. Before writing, scan
   your own draft for `AKIA`, `-----BEGIN`, `token=`, `password=`,
   `secret=` and 32 or more hex characters in a row; any hit stops the
   run with the line number.
5. Known issues and debt: traceability gaps, `TODO`, `FIXME` and `HACK`
   counts by directory (the Grep tool in count mode), open postmortem
   actions, "Noticed" sections in docs. Each item carries its ticket key (`<PREFIX>-<n>`);
   an unticketed item gets `HO-nn` and the flag `unticketed:`.
6. Licence inventory: dependency name, version and licence from the
   manifests and lock files where a licence field exists; otherwise
   `unconfirmed:`. Group by runtime, build and infrastructure.
7. Write `docs/handover/HANDOVER.md` (Write creates the directory). The
   sign-off page is the last section, with the entity, the client, the
   delivered version (last tag or commit), and blank signature lines.
8. Print the counts and the verdict.

## Output contract

```
## Handover pack: <client> by <entity> (<F> files read)
Sections: 12 filled, U unconfirmed
Environments: e   Accounts: a (0 credential values)   Repositories: r
Runbooks: b (s stale)   Alerts: m   Known issues: k (t unticketed)
Third-party components: c (l with licence, c-l unconfirmed)
Written: docs/handover/HANDOVER.md
Verdict: ready for sign-off | draft (U unconfirmed sections)
```

## Gotchas

- Never a credential value, not even a local development one, not even
  when it is already in the repository; report that as a known issue.
- Never query a production system to fill a section (ground rule 4).
  The pack describes production from documents and configuration only.
- Do not invent a hostname, URL or account to make a section look
  complete. `unconfirmed:` is the honest entry and the client can fill
  it in a minute.
- A runbook whose "Last verified" date is over ninety days old, or
  reads `not run`, is listed as stale in the index, not hidden.
- Another entity only when the user names it in the argument or the
  message; the default is the entity in `.bearing/company.json`.
