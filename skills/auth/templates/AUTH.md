# Authentication and authorisation: <scope>

<!-- Template guidance: every section below carries a comment saying what goes
     there (What), what a strong entry has (Good) and a one-line example
     (Example). Delete each comment when you fill its section. This is the
     record of who can call what, read by reviewers, vapt-report and the next
     engineer to add a route; the table below is filled from the accepted
     ADRs, never chosen here. -->

| Field | Value |
| --- | --- |
| Session model | <cookie session / JWT plus rotating refresh> (ADR <id>) |
| Authorisation model | <RBAC / ABAC for rules: ...> (ADR <id>) |
| Identity source | <own passwords (argon2id) / passkeys / OIDC provider> |
| Tenancy | <single / multi: column tenant_id on ...> |
| Middleware | `<path:line>` at the router root |
| Last reviewed | <YYYY-MM-DD> by <name> |

## Public routes

<!-- What: every route without an auth check, with the reason it is public.
     Good: the count matches "public P" from the route inventory; each route
     is named exactly as the router declares it; a public route missing from
     this table is a finding, not an omission.
     Example: "| `POST /auth/login` | the sign-in form; rate limited per
     account and per IP |" -->

| Route | Reason |
| --- | --- |
| `GET /healthz` | probe |

## Tokens and sessions

<!-- What: lifetimes, rotation, cookie flags, CSRF and how logout everywhere
     works, as built.
     Good: numbers, not "short"; access 15 min and refresh 7 to 30 days
     rotated on use with reuse detection; never a long-lived JWT as the
     session; "SameSite only" for CSRF carries its reason. Drop the mobile
     row only when there is no mobile client, and say so.
     Example: "| Refresh token lifetime | 14 days, rotated on use |" -->

| Item | Value |
| --- | --- |
| Access token lifetime | 15 min |
| Refresh token lifetime | <7 to 30> days, rotated on use |
| Reuse detection | revoke the token family, force re-login |
| Cookie flags | `HttpOnly; Secure; SameSite=Lax; Path=/` |
| CSRF | <double-submit token / SameSite only, with reason> |
| Logout everywhere | increment `users.session_version`; every token carries it |
| Storage on mobile | Keychain (iOS), EncryptedSharedPreferences (Android) |

## Login flows

<!-- What: one bullet per identity source in use, with its parameters.
     Good: delete the flows not built; OAuth is authorization code with
     PKCE only (implicit and password grants are gone); passwords are 12 or
     more characters with a breached-password check and no composition
     rules or forced rotation.
     Example: "Passkey: WebAuthn, relying party id `app.ledgerly.in`,
     resident keys yes, attestation none." -->

- Password: argon2id (memory 64 MiB, iterations 3, parallelism 1), breached-password check, rate limit per account and per IP, generic error on failure.
- Passkey: WebAuthn, relying party id `<domain>`, resident keys <yes/no>, attestation none.
- OAuth / OIDC: authorization code with PKCE; `id_token` checked for `iss`, `aud`, `exp`, `nonce`; provider list: <...>.

## Authorisation

<!-- What: the roles and resources, where the matrix lives, and the result
     of the last IDOR audit.
     Good: the unscoped count and list come from the "loads by id" line of
     the last run, each site as path:line; tenant scoping happens in the
     query, not after it; say "single tenant" when there is no tenant
     column. Front-end guards do not count as checks.
     Example: "Unscoped loads found at the last audit: 1
     (internal/invoice/handler.go:88)." -->

Roles: <list>. Resources: <list>. The matrix lives in
`docs/security/permission-matrix.md` and every cell is a test.

Resource-level rule: every load by id is scoped by owner or tenant in
the query. Unscoped loads found at the last audit: <N> (<list or none>).

## Open items

<!-- What: every gap this document admits: an unscoped load, a public route
     without a reason, a flow not yet built.
     Good: each row has a named owner and a task id, so it can be chased;
     "none" when the audit found nothing.
     Example: "| Scope `GetInvoiceByID` by tenant_id | Priya Nair |
     LED-PP-214 |" -->

| Item | Owner | Task |
| --- | --- | --- |
