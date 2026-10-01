---
name: nextjs
description: 'Next.js house rules (App Router, React 19, server components, server actions with Zod, Tailwind, shadcn/ui). Load before writing or changing Next.js code. Use when asked for "an App Router page", "a new route".'
allowed-tools: Read, Grep, Glob, Bash(pnpm install:*), Bash(pnpm run:*), Bash(pnpm exec:*), Bash(pnpm audit:*), Bash(make:*), Bash(npm run:*)
---

# nextjs

The Next.js stack on this standard: Next 16 App Router with React 19 and
Cache Components (`"use cache"`, `cacheLife`, `cacheTag`), server
components by default and `"use client"` only where a hook or an
event handler needs it, server actions validated with Zod after an
authorisation check, TypeScript strict, Tailwind v4 with shadcn/ui, Zod at
every boundary, env split into public (`src/env.ts`) and server-only
(`src/env.server.ts`), vitest plus Testing Library for units, Playwright
against the production build, ESLint flat config (`eslint-config-next`
plus type-checked rules), Prettier, pnpm, and a standalone-output image.

Not this: `react` is the client-only stack (Vite, TanStack). Choose
Next when pages must render on the server (SEO, first paint, data close
to the request); choose React when the app lives behind a login and an
API already exists.

## Inputs

- Source files: the repository as it is; no scaffold is needed. A
  different layout is handled under "On a foreign layout".
- Gate: `make check` when a Makefile has that target; else the native
  commands under Commands, one by one.
- `references/guidelines.md` and `references/review-checklist.md` ship
  with this skill. `bearing:new-repo` and `bearing:ci-pipeline` are suggestions for a
  repository without a Makefile or a pipeline, never prerequisites.

## When this skill is active

- Writing or changing `.ts` or `.tsx` files under `src/app` or a Next
  project: apply `references/guidelines.md`. Read it once per session.
- Reviewing a diff with Next files: apply `references/review-checklist.md`
  and report as under "Reviewing" below.
- Scaffolding (`new-repo next-app <Name>`): `templates/` holds the
  skeleton and configs; `bin/brg-scaffold` in the bearing plugin copies them. Do not hand-copy.
- Generating CI (`bearing:ci-pipeline`): `templates/.gitlab-ci.yml` is the source.

## Layout

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

## On a foreign layout

Hard rules anywhere: 1, 2, 3, 4 and 8. Advisory: the directory layout,
`src/`, shadcn/ui, Tailwind tokens (rule 7 applies only where Tailwind
is configured), pnpm and the Makefile targets: use the styling, data
library and package manager the repository already has (a Pages Router
app keeps `getServerSideProps` until an ADR moves it); propose a switch
in an ADR, never inside a feature change. Rule 4 in its written form needs
`cacheComponents`; an app without it (Next 15, or 16 not yet migrated)
keeps the fetch-level model, where every `fetch` names its cache and a
mutation calls `revalidateTag` or `revalidatePath`. A Next 15 app keeps
`middleware.ts`. Keep the majors the repository pins and write their API:
Next 15 has no `updateTag`, `"use cache"`, `cacheLife` or `cacheTag`; Zod 3
has `parsed.error.flatten()` and `z.string().email()`, where Zod 4 has
`z.flattenError`, `z.prettifyError` and `z.email()`. Check `package.json`
before the first line. Say which rule was relaxed.

Screens as code: screen-design writes each screen as a `*.screen.tsx`
that renders the real view components with fixture props, and the route
wires the same components to live data. The gallery is a client
component, so a screen file reaches the browser with all it imports:
import the presentational view (in a file of its own), never the server
component that fetches or anything that imports `server-only`. Next.js
has no `import.meta.glob`, so `make design-registry` lists the screens;
`make dev` runs it first and `make check` fails when the list is stale.

## Rules that matter most

1. Server by default. A file gets `"use client"` only for a hook, an event
   handler or a browser API, and the boundary sits as low in the tree as
   it can. A page marked client because one button needs state is a finding.
2. Every server action authorises before it validates and validates before
   it acts: `requireSession()`, then `schema.safeParse(formData)`, then the
   ownership check, then the work through the API. An action is a public
   POST endpoint. The tenant (customer, organisation) comes from the
   session only; a resource id from the form or a bound argument is input,
   so the action loads that resource and compares its owner with the
   session before it writes, whenever the backend does not scope the call
   itself (a service token that can reach every tenant never does).
3. Nothing secret reaches the client: server values are read only through
   `src/env.server.ts` (which imports `server-only`); `NEXT_PUBLIC_` is for
   public values and is inlined at build time.
4. Caching is opt-in and stated in the feature function: reads are
   request-time by default; data that may lag is a `"use cache"` function
   with `cacheLife` and `cacheTag`. A server action that changes it calls
   `updateTag` (the user sees the write at once); a route handler or
   webhook calls `revalidateTag(tag, "max")`. No route segment `dynamic`,
   `revalidate` or `fetchCache`, no `unstable_cache`.
5. Route handlers serve machines (probes, webhooks, downloads); server
   actions serve forms. A form posting to a route handler, or a handler
   called from a component, is a finding.
6. Streaming: slow data sits under a `Suspense` boundary with a fallback
   that has `role="status"`; `loading.tsx` covers the route; `error.tsx`
   catches the segment and offers `reset`.
7. Tailwind uses the tokens in `src/app/globals.css`; shadcn components are
   copied in with the CLI and used as-is. Arbitrary values are a finding.
8. `make check` = Prettier check, ESLint (zero warnings), `tsc --noEmit`,
   vitest with coverage floors, `pnpm audit`. CI adds `next build` and
   Playwright. `pnpm audit` needs the registry: offline, `vuln` records a
   skip, never a pass. With no `node_modules` and no network nothing can
   run; do not try an install, say which checks were not run. `next/image` for images, `next/font/local` for fonts.

## Commands

Each target is used when the Makefile has it; the command after the
colon is the native form (`pnpm exec <cmd>`, or the repository's `npm run`
scripts).

```
make setup      # pnpm install, Playwright chromium, git hooks
make dev        # next dev on :3000 with .env.local
make check      # prettier --check . ; eslint . ; tsc --noEmit ; vitest run --coverage ; pnpm audit
make fix        # prettier --write . ; eslint --fix .
make build      # next build (standalone output)
make test-e2e   # playwright test (builds, then next start on :3000)
make test-e2e-matrix  # the same specs on chromium, firefox, webkit and two phones (CI after merge)
make test-visual      # e2e/visual/ against committed baselines, in the Playwright image
make test-visual-update  # rewrite baselines in the image; commit them on their own
make bundle-budget    # gzipped JavaScript under BUNDLE_BUDGET_KB (after make build)
make lighthouse       # Lighthouse CI: LCP, CLS, TBT and score from lighthouserc.json
pnpm dlx shadcn@4.21.0 add button   # add a shadcn component
```

## Traps a careful generalist still misses

- Every exported function in a `"use server"` file is a POST endpoint,
  callable from any browser with any arguments, whether or not a form uses
  it. A helper such as `removeInvoices(orgId, ids)` exported beside the
  actions is an open door; keep helpers unexported or in a `server-only`
  module.
- `action.bind(null, orgId)` in a server component does not make `orgId`
  trusted: the bound value travels through the browser, and the action is
  an endpoint any client can call with any first argument. Hidden inputs
  are the same. Neither carries authority; read the tenant from the
  session inside the action.
- `redirect()` and `notFound()` work by throwing. A `try` around
  `requireSession()` or around code that redirects turns "signed out" into
  a generic error message; keep them outside the `try` or call
  `unstable_rethrow(e)` first in the `catch`.
- React 19 resets an uncontrolled form when its action settles, so a
  failed save wipes what the user typed and shows the old `defaultValue`.
  Return the submitted values in the error state and render them as the
  defaults (key the form on the state so they apply).
- Tags match exactly: the mutation expires the string the read declared
  (`invoices:<orgId>`, not `invoices`), for every cached read the write
  changed (lists, summaries, counts).
- A `"use cache"` entry is keyed on its arguments only. Anything it reads
  from module scope or a closure over request data is shared by every
  caller: one tenant's result served to another.
- Batch actions: one ledger failure in `Promise.all` throws away the
  outcome of the rest. Settle each item, return which succeeded and which
  failed, expire the tags anyway, and keep the batch size bounded.
- A read schema stays loose for legacy rows; the write schema carries the
  current rules. A legacy row the write rules reject cannot be edited in
  place: say so on the page and refuse it in the action.
- Tests prove the boundary, not the mock: the "another tenant" test stubs
  the API (or `fetch`) to return a resource owned by someone else and
  asserts no write was sent. Stubbing your own ownership helper to say
  "not yours" tests nothing.

## Reviewing

Verdict first (merge, merge after fixes, do not merge), blocking findings
before the rest. Each finding: severity, file and function or line, a
failure scenario a user or attacker would hit, the fix. When the request
carries a deadline, say what the smallest safe release is. Read the
docs and ADRs in the repository before the diff: they say who the backend
trusts and what may never happen. Report no finding the code does not
support, list what was checked and found clean, and say which checks
were not run.

## Gotchas

- Server components cannot be mocked from Playwright: their fetch runs on
  the server. `playwright.config.ts` points `API_URL` at the app's own
  `/api` route handlers so the health card has a real answer.
- A server component is an async function; unit tests `await` it and
  render the result. `server-only` is aliased to an empty module in
  `vitest.config.ts`; the real one guards the build.
- `next build` evaluates `src/env.server.ts`, so a required server variable
  with no default fails the build, not the first request. Defaults for
  non-secrets, none for secrets.
- Under Cache Components an uncached read, `cookies()`, `headers()`,
  `searchParams` or `connection()` outside a `Suspense` boundary fails
  `next build`. Wrap that part in `Suspense`; the rest of the page is the
  prerendered shell. `new Date()`, `Math.random()` and `crypto.randomUUID()`
  in a prerendered path fail the build too.
- A `GET` route handler that reads nothing dynamic is prerendered at build.
  Probes call `await connection()` first, or they answer with build-time
  data forever.
- `cacheLife`, `cacheTag`, `updateTag` and `revalidateTag` changed in Next
  16 (`revalidateTag` now takes a profile). The version-matched docs ship
  in `node_modules/next/dist/docs/`; read the page before writing a Next API
  from memory. `agentRules: false` in `next.config.ts` keeps `next dev` from
  editing `AGENTS.md`.
- `useActionState` needs a client component; the action it calls stays in
  a `"use server"` file. The form's HTML validation attributes are a
  convenience; the action's Zod schema is the rule.
- `src/proxy.ts` is the Next 16 name for middleware (export `proxy`). It
  runs on the Node.js runtime before every matched request, but it is
  still no place for a database call or heavy work. Request id and
  redirects only; authorisation is repeated in the page or action.
