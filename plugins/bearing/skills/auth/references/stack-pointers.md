# Where the auth middleware sits, per stack

One place, at the root of the router, so a new route is protected by
default and public routes opt out by name.

| Stack | Middleware placement | Session / token storage | Notes |
| --- | --- | --- | --- |
| Go (`net/http`, chi, gin) | `r.Use(auth.Middleware)` on the top router; public routes in a `r.Group` without it | cookie session in Postgres or Redis; JWT verified with a cached JWKS | context carries the principal; handlers call `auth.Principal(ctx)` |
| Python (FastAPI) | a router-level `dependencies=[Depends(current_user)]`; public routers omit it | `itsdangerous` signed cookie or JWT via `python-jose` | never `Depends` per endpoint; forgetting one is the bug |
| Python (Django) | `MIDDLEWARE` entry plus `LoginRequiredMiddleware`-style default deny | Django sessions table | DRF: `DEFAULT_PERMISSION_CLASSES = [IsAuthenticated]` |
| Node (Express, Hono) | `app.use(auth())` before route registration; public routes registered first or allow-listed | cookie session (`express-session` with a store) or JWT | `app.use` order is the placement |
| TanStack Start / Next.js | a server middleware or route loader guard on the server; the client guard is UX only | cookie session | every server function checks the principal itself |
| React (SPA) | none; the API enforces | token in memory, refresh in an `HttpOnly` cookie | never `localStorage` for tokens |
| React Native | none; the API enforces | `expo-secure-store` or Keychain / Keystore | biometric unlock gates the token read, not the API |
| Android | `OkHttp` interceptor adds the token; refresh in an `Authenticator` | `EncryptedSharedPreferences` or Keystore-backed | `Authenticator` handles 401 once, then logs out |
| iOS | `URLProtocol` or a request adapter adds the token | Keychain (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`) | ASWebAuthenticationSession for OAuth |

## Resource scoping patterns

- SQL: `WHERE id = $1 AND tenant_id = $2` in the same statement; a
  repository method that takes the tenant from the principal, never
  from the request body.
- ORM: a default scope or manager bound to the tenant (`objects.for_tenant(t)`),
  and a test that the unscoped manager is not used in handlers.
- Document stores: the tenant id in the partition or shard key.

## Token rotation

Refresh token families: each refresh issues a new refresh token and
records the parent. Presenting a refresh token that was already used
revokes the whole family and ends every session for that user.
