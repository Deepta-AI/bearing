---
name: threat-model
description: 'Writes a STRIDE threat model before code: assets, trust boundaries, entry points, threats rated, mitigations mapped to stories. Use when asked to "threat model this", "STRIDE analysis" or "what could an attacker do".'
argument-hint: "<feature or system> [path to HLD]"
allowed-tools: Read, Write, Grep, Glob, Skill, Bash(ls:*), Bash(mkdir:*), Bash(git branch:*), Bash(python3 *skills/threat-model/scripts/threats_check.py*)
---

# threat-model

A threat model lists what an attacker wants, where they can get in, and
what stops them, before the code is written. It feeds `vapt-report` and
`/security-review`, which check that the mitigations exist. A model with
zero threats for a feature that touches auth, payments, PII or external
input is not a clean bill; it is a failure of the model.

## Inputs

- Scope: looks in `$ARGUMENTS`; if absent, asks one question.
- HLD: looks in the path given, else `docs/design/*-hld.md`; if absent,
  the scope is described from the code and marked "assumption:".
- Trust boundaries: looks in `docs/architecture/*-c4.md`; if absent,
  derived from compose, k8s and env hosts, then from the HLD, marked
  "assumption:".
- Entry points: looks in `api/openapi.yaml`; if absent, routes grepped
  from the code (the patterns `openapi-spec` lists), consumers, cron
  jobs, upload handlers and admin screens.
- Stories: looks in `docs/product/backlog.md`; if absent, `Serves:
  unnumbered` and every planned mitigation is a `new story:` title.
- Assets: derived from the sensitive classes the grep finds and the PRD;
  if zero, asks one question for what the feature protects. Zero assets
  and zero entry points after that stops the skill: "name the assets or
  the routes in scope".
- Template: `templates/threat-model.md` in this skill.
- Gate: `scripts/threats_check.py` in this skill, Python 3 only, run from
  the repository root; it reads the written model, the backlog and the
  cited files, never the model's own counts.

## Steps

**Revising.** When the output file already exists, this run is a
revision: read `${CLAUDE_PLUGIN_ROOT}/skills/adr/references/revision-protocol.md`
and follow it (version line, changes table, superseding ADR,
critic on changed sections, downstream list). Threat ids are stable across revisions: a threat that no longer applies is marked `retired in v<n+1>` with the reason, never deleted or renumbered, because vapt-report reports cite the ids.

1. Scope from `$ARGUMENTS`. Read `templates/threat-model.md`, the HLD
   (given path or `docs/design/*-hld.md`), the container diagram
   (`docs/architecture/*-c4.md`) for trust boundaries, `api/openapi.yaml`
   for entry points, and the stories for the ids served. Grep the scope
   for auth, session, token, payment, charge, webhook, upload, PII
   fields (email, phone, address, pan, aadhaar, card). Record which
   sensitive classes apply.
2. Assets: what an attacker wants (credentials, PII, money, availability,
   audit integrity), where each lives, its owner. Zero assets: ask the one
   question under Inputs and continue with the answer.
3. Trust boundaries: each edge in the container diagram that crosses a
   boundary (internet to ingress, service to store, service to external,
   user role to admin role), the protocol, the auth on it. No diagram:
   derive from the HLD and mark the list "assumption:".
4. Entry points: every route, consumer, cron, upload, callback and admin
   screen in scope, with its auth requirement. Count them.
   Abuse-path pass, when the scope already has code and the
   `security-threat-model` skill is installed: load it through the
   Skill tool and apply three of its steps to the assets, boundaries
   and entry points above: its attacker model (capabilities and,
   written out, non-capabilities), its threats as multi-step abuse paths
   tied to an asset, and its assumption check (the assumptions that
   change the ranking, at most three questions to the user, answered
   before step 5). It contributes evidence-anchored abuse paths and
   severity calibration; it does not write the file. Do not produce its
   `<repo>-threat-model.md`, its `TM-nnn` ids or its table: every abuse
   path becomes one or more `T-nn` rows in step 5 under the STRIDE
   category it realises, and a threat that needs a listed
   non-capability is dropped or set to likelihood L with the reason.
   For a design with no code yet, or when the skill is not installed,
   write "abuse-path pass: not run (<reason>)" and step 5 stands alone.
5. Threats: for each entry point and boundary, walk the six STRIDE
   categories (spoofing, tampering, repudiation, information disclosure,
   denial of service, elevation of privilege). Each threat gets an id
   `T-nn`, likelihood and impact (L, M, H), a mitigation that is either
   existing code (`file:line`), a story id (`US-nn-nnn`), or `new story:
   <title>`, and a status: mitigated, planned, unmitigated. Skipping a
   category is written as "considered, none" with the reason.
6. Residual risks: every planned or unmitigated threat, with an owner and
   a revisit date. An owner is a rotation or role, not a person's name.
7. Zero entry points and zero boundaries after the fallbacks: stop with
   "nothing in scope; name the routes or the boundaries".
8. Write `docs/security/threat-model-<kebab>.md`, then run the gate:
   `python3 "${CLAUDE_PLUGIN_ROOT}/skills/threat-model/scripts/threats_check.py" docs/security/threat-model-<kebab>.md`.
   It fails on a threat id not of the form `T-nn` or repeated, a
   mitigation that is not an existing `path:line`, a backlog story id or
   `new story: <title>`, "handled by the framework", an empty mitigation,
   and a sensitive scope with zero threats; and on zero threats read. Fix
   what can be fixed and rerun. A sensitive scope still at zero threats
   stays `FAILED`: set the status to Draft with the reason on line one.
   Print the contract with the gate's lines.

## Output contract

```
## Threat model: <scope>
Path: docs/security/threat-model-<kebab>.md
Serves: US-..., REQ-..., ADR-...
Sensitive classes: auth, payments, PII, external input (or none)
Assets: N   Boundaries: N (assumption: K)   Entry points: N
Abuse-path pass: run (security-threat-model) | not run (<reason>)
<threats_check.py "Threats by category:" line, verbatim>
<threats_check.py "threat-model:" counts line, verbatim>
New stories needed: K
- new story: <title> (mitigates T-nn)
Residual risks: N (owners missing: K)
<threats_check.py "Gate:" line, verbatim>
Revision: v<n> -> v<n+1>, sections changed C, ADRs superseded S, downstream D | v1 (new)
```

A count the script did not print is not written.

## Gotchas

- "Handled by the framework" is not a mitigation. Name the middleware,
  the file and the line, or make it a story.
- Authorisation threats are per record, not per role. "Admin only" does
  not answer "can tenant A read tenant B's invoice".
- External input includes webhooks, file uploads, imported CSVs and
  third-party callbacks, not only the public API.
- Never write real secrets, tokens or PII samples in the model, even to
  illustrate a threat.
- No em dashes; short sentences; ids stable once written so `vapt-report`
  can cite them.
