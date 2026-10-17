# nextjs: folder layout, an app that owns its data, screens as code

Read when you place a new file, replace the scaffold's API layer with a database, or write a screen file.

```
src/app/layout.tsx                 root layout: metadata, viewport, html and body
src/app/page.tsx                   a route; server component unless it says otherwise
src/app/{loading,error,global-error,not-found}.tsx   route states; error files are client
src/app/api/<probe>/route.ts       route handlers: /api/healthz, /api/readyz, webhooks
src/features/<feature>/schemas.ts  Zod schemas; types are z.infer
src/features/<feature>/api.ts      server-only fetch functions with an explicit cache option
src/features/<feature>/actions.ts  "use server": authorise, validate, act, return state
src/features/<feature>/components/ server components by default; "use client" per file
src/features/<feature>/screens/    <id>-<name>.screen.tsx: every state of a screen from fixtures
src/design/                        the design gallery at /__design (dev, or DESIGN_GALLERY=1)
src/app/%5F%5Fdesign/              its routes; %5F is how the App Router spells a leading _
src/design/screens.generated.ts    the screen list, written by make design-registry, checked by make check
src/components/ui/                 shadcn output (33 components): added with the CLI, never hand-edited
src/lib/                           api client (server-only), auth, utils (cn)
src/env.ts, src/env.server.ts      public and server configuration, both Zod-parsed
src/proxy.ts                       request id, redirects, rewrites; nothing heavy
e2e/                               Playwright specs against next build and next start
Makefile                           the only entry point: help setup dev check fix test doctor
```

The scaffold assumes a separate API (`API_URL`, `src/lib/api.ts`, the
health card that calls it). When the Next.js app is itself the backend (its
route handlers or actions write a database, as with Supabase or a
Postgres driver, and an ADR says so), replace that layer rather than
keep it beside the real one:

- `src/server/` (every file imports `server-only`): `env.ts` parsed on
  first use, not at module load, so `next build` needs no production
  secret; `http/` with the one error type and the route wrapper (request
  id, body cap, content type, schema parse, one mapping to the contract's
  envelope); `db/` with the clients; `providers/` with a port and a fake
  per third party.
- Delete `src/env.server.ts`, `src/lib/api.ts`, the scaffold's
  placeholder auth and its example features once nothing imports them;
  `readyz` asks the database, not an API.
- Migrations live with the database's tool (`supabase/migrations/`, a
  `migrations/` folder for a driver), tested on a real database by a
  `make test-db` target that fails on zero test files; it is a CI job, not
  part of `make check`, because it needs Docker.

Screens as code: screen-design writes each screen as a `*.screen.tsx`
that renders the real view components with fixture props, and the route
wires the same components to live data. The gallery is a client
component, so a screen file reaches the browser with all it imports:
import the presentational view (in a file of its own), never the server
component that fetches or anything that imports `server-only`. Next.js
has no `import.meta.glob`, so `make design-registry` lists the screens;
`make dev` runs it first and `make check` fails when the list is stale.
