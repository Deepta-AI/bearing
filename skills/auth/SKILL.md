---
name: auth
description: 'Builds authentication and authorisation: sessions or tokens, passkeys, OAuth, RBAC, tenant isolation, IDOR checks, a permission matrix as tests. Use when asked to "add login", "roles and permissions" or "who can access".'
argument-hint: "<feature or service> [--design-only] [--audit]"
allowed-tools: Read, Write, Edit, Grep, Glob, Skill, Bash(ls:*), Bash(mkdir -p:*), Bash(make check:*), Bash(make test:*), Bash(git branch:*), Bash(git diff:*), Bash(go test:*), Bash(pnpm exec vitest:*), Bash(uv run pytest:*), Bash(./gradlew test:*), Bash(swift test:*)
---

# auth

Authentication says who; authorisation says what, on which resource,
in which tenant. Most breaches are the third clause missing: a valid
user reading someone else's row. The permission matrix is a test table,
so every cell is a test that runs.

Not this: `threat-model` finds what could go wrong; `vapt-report`
proves it did not. This skill builds the controls between the two.

## Inputs

- Scope: `$1`, a feature or service; if absent, the whole API.
  `--design-only` writes the docs and tests and no middleware;
  `--audit` runs steps 2, 4 and 6 and changes nothing.
- Decisions: accepted ADRs under `docs/adr/` for session versus token
  and RBAC versus ABAC; if absent, the `tech-decision` protocol in step 1.
- Routes: the router files per stack (`chi`, `gin`, `net/http` mux;
  FastAPI, Django `urls.py`; Express, Hono, TanStack server routes;
  Android and iOS have none: their scope is token storage only).
- Roles and resources: `docs/product/backlog.md` and the stories'
  actors; if absent, from the existing role enum in code; if none, one
  question: "which roles exist, and which resources do they act on?".
- Tenancy: a `tenant_id` or `org_id` column in the schema; absent means
  single tenant and the matrix drops that column, said in the report.
- Stack pointers: `references/stack-pointers.md` in this skill.
- Templates: `templates/AUTH.md` to `docs/security/AUTH.md`,
  `templates/permission-matrix.md` to `docs/security/permission-matrix.md`,
  written only when step 7 says so.

## Steps

1. Decisions first, through `tech-decision`, one question at a time,
   skipped when an accepted ADR, the code, or the request with the
   backlog already settles it (cite which; roles the backlog names
   settle RBAC). Record by the repository's own practice: where it keeps
   ADRs (`docs/adr/` with an accepted "record decisions" ADR, or an ADR
   that says a case like this one needs its own decision), a decision
   this change builds on is written as the next-numbered ADR in that
   repository's format, status Accepted when the user answered, else
   Proposed (awaiting the user), because code built on an unrecorded
   decision gives the reviewer nothing to approve; an older ADR it
   narrows gets a Status note, never a rewritten Decision. Where the
   repository keeps no ADRs and the request is a fix, start no ADR
   directory: the open question goes in the final message. Keys:
   session or token (cookie session for a browser app on one origin; short-lived JWT plus rotating refresh for
   mobile and third-party clients; never a long-lived JWT as the
   session), RBAC or ABAC (RBAC until a rule needs an attribute of the
   resource; then ABAC for that rule only), identity source (own
   passwords with argon2id, passkeys, or OIDC from a provider).
2. Route inventory: grep the router files; print "routes: N, with auth
   check K, public P". N=0: stop with "0 routes found under <path>".
   Every public route is listed by name (in AUTH.md when step 7 writes
   it, else in the final message) or it is a finding.
3. Permission matrix: roles by resource by action, a tenant column when
   multitenant, one row per cell with the expected status (200, 403,
   404), from `templates/permission-matrix.md` (a file only when step 7
   writes docs). Print "cells: N".
4. IDOR check: grep loads by id (`GetByID`, `FindByID`, `findUnique`,
   `get_object_or_404`, `.where(id`, `WHERE id =`) and count sites that
   scope by owner or tenant in the same query or in the handler. Print
   "loads by id: N, scoped K, unscoped U" and list every unscoped site
   as `path:line`. Lists loaded by a parent id (`ForPatient`,
   `ByOwnerID`, `WHERE patient_id =`) count as loads by id: a list
   keyed only by another tenant's parent id leaks the same rows. N=0 in
   a service with routes is itself a finding.
5. Implement unless `--design-only`, following the stack pointer. Build
   the roles, permissions and rules the stories and the matrix state and
   nothing more. The mechanisms below go in because they make the
   stated rules safe (the `session_version` column is cheap and makes a
   later logout-everywhere one increment), but a route, a permission or
   a role grant no story asks for (a `/logout/everywhere` endpoint, a
   `session:end` permission) is listed under "Not done" as a
   recommendation, not added.
   middleware placed once at the router root, not per handler; cookie
   flags `HttpOnly; Secure; SameSite=Lax`; CSRF protection (a token, or an
   `Origin` check) only when this change creates or changes the cookie
   session itself, and then together with the change to every client that
   sends state-changing requests. When the sessions already exist and the
   task is authorisation or another credential, missing CSRF protection is
   a finding with the client work it needs, listed under "Not done", not
   middleware added: a check that turns an existing client's request into
   a 403 is a regression, not hardening. Token signing keys come from configuration (an env var or
   the secret store), are refused at start when missing or shorter than
   32 bytes, and are never generated at start (every restart would log
   everyone out and replicas would disagree); every existing path that
   ends a user's web sessions (logout everywhere, deactivation, password
   or role change: grep for where sessions are deleted) ends their
   tokens through the same state, checked on each request, not when the
   token expires; access token 15 minutes, refresh 7 to 30 days rotated on
   use with reuse detection revoking the family; a `session_version` on
   the user so logout everywhere is one increment; OAuth only as
   authorization code with PKCE; OIDC `id_token` checked for `iss`,
   `aud`, `exp`, `nonce`; passkeys with the relying party id pinned;
   mobile tokens in Keychain or EncryptedSharedPreferences, never in
   plain storage.
6. Tests: one test per matrix cell, generated as a table-driven test in
   the stack's shape, named `TC-AUTH-<role>-<resource>-<action>`. Add
   one IDOR test per resource (user A reads B's row, expects 404 or
   403) and, when logout everywhere is built, one test for it. Run; print "matrix tests: N of
   N cells, passed N". Cells and tests must be equal.
7. Write `docs/security/AUTH.md` (and `permission-matrix.md` beside it)
   from the templates when this run adds or changes a credential or
   session mechanism, when `--design-only`, or when the files already
   exist: the decisions, the public routes, the token lifetimes and
   where the middleware sits. An authorisation fix in a repository
   without them keeps the matrix in the test table and the contract in
   the final message. Print the contract.

## Output contract

```
## Auth: <scope> (<session | token>, <RBAC | ABAC>, <single | multi> tenant)
Routes: N, with auth K, public P: <METHOD /path, ...>
Matrix: R roles x S resources, cells N; tests N of N, passed N
IDOR: loads by id N, scoped K, unscoped U  <path:line ...>
Tokens: access <m> min, refresh <d> days rotating, logout everywhere via <mechanism>
ADR: docs/adr/<...> (<Accepted | Proposed>) | none, repository keeps no ADRs   Docs: <paths> | none
Not done: <list> | none
```

## Gotchas

- A 403 on someone else's row confirms the row exists. Return 404 for
  resources the caller may not know about; the matrix says which.
- Checking the role in the handler and forgetting the tenant is the
  common IDOR: role admin of tenant A reading tenant B. Scope in the
  query, not after it.
- Before adding a check to an existing route, grep the clients in the
  repository for calls to it: a new required header or token that a
  client does not send is a breaking change, whatever it protects.
- A JWT cannot be logged out. Without a short lifetime plus a server
  side version or denylist, "logout" is a client deleting a string.
- A rule on a field (notes only for doctors) holds on every response
  that carries the field. Grep the field across handlers, list views,
  exports and summaries; a second struct that copies it under another
  name is the usual leak.
- A committed signing key or secret is reported by where the literal
  still appears after the change: grep the whole repository and list
  what remains (tests proving it is refused, docs quoting it) by
  `path:line`. Say "removed from code paths", not "gone", unless the
  grep count is 0.
- Front-end route guards are UX, not authorisation. Every check the
  matrix names runs on the server.
- Password rules: length 12 or more, no composition rules, a breached
  password check; never a forced rotation, never a hint stored.
- OAuth "implicit" and "resource owner password" flows are gone; a
  provider example that shows them is out of date.
- Rotating refresh tokens without reuse detection just doubles the
  tokens a thief can use.
- The final message names every public route and every unscoped load by
  `path:line`, not only their counts, so the user can check each one
  without opening AUTH.md.
