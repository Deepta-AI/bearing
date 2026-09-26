---
name: nextjs
description: 'Conventions for Next.js: Next 16 App Router, React 19, server components, server actions with Zod, Tailwind v4, shadcn/ui, Playwright. Use when writing, reviewing or scaffolding "Next.js" or "App Router" code.'
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
  with this skill. `new-repo` and `ci-pipeline` are suggestions for a
  repository without a Makefile or a pipeline, never prerequisites.

## When this skill is active

- Writing or changing `.ts` or `.tsx` files under `src/app` or a Next
  project: apply `references/guidelines.md`. Read it once per session.
- Reviewing a diff with Next files: apply `references/review-checklist.md`
  and report in the reviewer format.
- Scaffolding (`new-repo next-app <Name>`): `templates/` holds the
  skeleton and configs; `bin/brg-scaffold` copies them. Do not hand-copy.
- Generating CI (`ci-pipeline`): `templates/.gitlab-ci.yml` is the source.

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
src/components/ui/                 shadcn output: added with the CLI, never hand-edited
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
`middleware.ts`. Say which rule was relaxed.

## Rules that matter most

1. Server by default. A file gets `"use client"` only for a hook, an event
   handler or a browser API, and the boundary sits as low in the tree as
   it can. A page marked client because one button needs state is a finding.
2. Every server action authorises before it validates and validates before
   it acts: `requireSession()`, then `schema.safeParse(formData)`, then the
   work through the API. An action is a public POST endpoint.
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
   Playwright. `next/image` for images, `next/font/local` for fonts.

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
pnpm dlx shadcn@latest add button   # add a shadcn component
```

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
