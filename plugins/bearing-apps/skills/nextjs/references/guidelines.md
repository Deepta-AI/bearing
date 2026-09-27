# Next.js guidelines

## Project shape

- `src/app/` holds routes and route states only: `layout`, `page`,
  `loading`, `error`, `global-error`, `not-found`, `template`, and
  `api/<name>/route.ts`. A page composes feature components; it does not
  hold business logic.
- `src/features/<feature>/` owns one domain: `schemas.ts` (Zod),
  `api.ts` (server-only fetch functions), `actions.ts` (server actions),
  `components/` (server by default, client per file).
- `src/components/ui/` is shadcn output. Add with `pnpm dlx shadcn@4.21.0
  add <name>`, never hand-edit. `src/components/` holds shared components
  built on top of them.
- `src/lib/` holds the API client, auth helpers, `cn`. No dumping ground.
- A component file under 200 lines with one component exported.

## Server and client components

- Everything is a server component until it needs `useState`, `useEffect`,
  an event handler, a browser API or a context. Then that leaf, and only
  that leaf, gets `"use client"`.
- Push the client boundary down: a server page renders a client
  `<Filters />` and passes it plain props; it does not become client
  itself.
- Props across the boundary are serialisable: strings, numbers, plain
  objects, arrays, `null`. No functions except server actions, no class
  instances, no Dates (send ISO strings).
- Every prop that crosses the boundary is serialised into the HTML and
  the RSC payload. Pass the fields the client component renders, not the
  API record: `<Avatar name={user.name} />`, never `<Avatar user={user} />`
  for one field. Pass one value once; the same list sent to two client
  children ships twice.
- Server components can be `async` and `await` data directly. They never
  import a client hook and never hold state.
- Server-only modules import `server-only` at the top so a client import
  fails the build instead of leaking.
- Module scope on the server is shared by every request the process
  serves at once. A `let currentUser` or a mutable map written during a
  render or an action leaks one user's data into another's response.
  Request data travels as arguments and props; module scope holds only
  immutable config and caches keyed on purpose (`React.cache` is already
  per request).
- Client components can render server components passed as `children`;
  they cannot import them.

## Data fetching and caching

- Fetch on the server, in the component that needs the data or in a
  feature `api.ts`. No `useEffect` fetch on the client for data the server
  can render; TanStack Query only for client-driven, interactive data.
- `cacheComponents: true` is on (`next.config.ts`). Every read is
  request-time unless it opts in, and caching is decided in the feature
  function, not on the `fetch`:
  - live data: a plain call, rendered under `Suspense`.
  - data that may lag: a function with `"use cache"` at the top,
    `cacheLife("minutes")` (or `hours`, `days`, `max`) and
    `cacheTag("invoices")`. Arguments become part of the cache key; the
    function is async and its arguments and result are serialisable.
  - cookies and headers are read outside the cached function and passed
    in as arguments; a `"use cache"` body that calls `cookies()` fails.
- After a mutation: `updateTag("invoices")` in the server action, so the
  user who wrote sees the write on the next render; `revalidateTag(
  "invoices", "max")` from a route handler or webhook (stale while it
  refreshes); `revalidatePath` only when no tag fits. `updateTag` throws
  outside a server action.
- Route segment `dynamic`, `revalidate` and `fetchCache` are build errors
  under Cache Components, and `unstable_cache` and the fetch `next` option
  belong to the pre-16 model. Do not mix the two models in one app.
- `cookies()`, `headers()`, `params` and `searchParams` are async only:
  `await` them, inside a `Suspense` boundary.
- No request waterfalls. Independent reads start together: `const
  [user, invoices] = await Promise.all([getUser(id), listInvoices(id)])`,
  never one `await` after another. A read that needs a slow value starts
  as a promise and is awaited where it is used. Sibling async server
  components fetch in parallel; a parent that awaits before rendering its
  children makes them wait, so move the read into the child that uses it
  or under its own `Suspense`.
- Request deduplication: the same `fetch` URL and options within one
  render is fetched once; wrap other per-request reads in `React.cache`.

## Streaming and Suspense

- `loading.tsx` per route segment: instant navigation, then content.
- Slow components sit under `Suspense` with a fallback carrying
  `role="status"` and `aria-live="polite"`; the fast parts of the page
  stream first.
- `error.tsx` is a client component that receives `error` and `reset`;
  it keeps the layout, logs to the reporter, shows `digest` in
  production. `global-error.tsx` renders its own `html` and `body` and
  imports nothing from the app.
- `notFound()` from a server component or action renders the closest
  `not-found.tsx`; `redirect()` throws, so it is never inside `try`.

## Server actions

- `"use server"` at the top of `actions.ts`, one action per exported
  function. Never inline an action inside a component that also renders
  secrets.
- Order inside every action: `requireSession()` (and ownership checks on
  the resource), `schema.safeParse(...)` on the form data, the work
  through the API, `updateTag` for each cached read the write changed,
  return a state.
- Return a discriminated state (`idle | ok | error`) with
  `z.flattenError(parsed.error).fieldErrors` (Zod 4; Zod 3 is
  `parsed.error.flatten().fieldErrors`); the client renders field errors
  and a status region. Never return an `Error` object. An error state
  carries the submitted values back so the reset form shows them.
- A 422 from the API maps onto the form's own fields by known key; unknown
  keys and the raw body become one general message.
- The client side is `useActionState(action, initial)` in a small
  `"use client"` form; `pending` disables the submit button.
- An action is a public POST endpoint whatever renders it: rate limit at
  the edge, size-limit inputs, never trust hidden fields or `.bind`
  arguments for authority. Every export of a `"use server"` file is such
  an endpoint; helpers live unexported or in a `server-only` module.
- `redirect()` and `notFound()` throw: never inside a `try` that swallows
  them (or `unstable_rethrow(e)` first in the `catch`).

## Route handlers

- `src/app/api/<name>/route.ts` for machines: probes, webhooks, file
  downloads, integrations that need a URL. A `GET` that reads nothing
  dynamic is prerendered at build; a probe or anything that must answer
  per request calls `await connection()` first.
- Validate the body with Zod, answer with `Response.json`, map errors to
  one envelope. A route handler never renders HTML.
- `/api/healthz` (process up) and `/api/readyz` (the API the app renders
  from answers) exist on every app; the image's healthcheck uses them.

## Routing and navigation

- `next/link` for navigation, `useRouter` only in client components that
  navigate after an action. `router.refresh()` re-renders server
  components; prefer `updateTag` in the action.
- Dynamic segments read `params` (async); search params are parsed with
  Zod before use, never read raw.
- Parallel and intercepting routes only with a documented reason; they
  are hard to debug and easy to misuse.

## Proxy

- `src/proxy.ts` (Next 16's name for middleware; the export is `proxy`)
  runs on the Node.js runtime before matched requests: request id,
  redirects by locale or auth cookie presence, rewrites. It cannot run on
  the edge; an app that needs the edge keeps `middleware.ts` and says so
  in an ADR.
- No database, no heavy import, no authorisation decision that the page
  or action does not make again. The matcher excludes `_next/static`,
  `_next/image` and the favicon.

## Images and fonts

- `next/image` for every image, with `width` and `height` or `fill`, and
  `sizes` for responsive images. `remotePatterns` lists each host.
  `priority` only on the largest above-the-fold image.
- `next/font/local` with a committed font file; `next/font/google`
  fetches at build and fails offline CI. System stack until a brand font
  is chosen.

## Configuration

- `src/env.server.ts` imports `server-only` and parses `process.env` with
  Zod at module load: an invalid variable fails `next build`. Defaults for
  what is safe to default, none for secrets.
- `src/env.ts` parses the public variables, each referenced by its full
  `NEXT_PUBLIC_` name so Next inlines it. Public means public: shipped to
  every browser.
- `next.config.ts`: `output: "standalone"`, `reactStrictMode`,
  `poweredByHeader: false`, explicit `remotePatterns`. No secrets.
- `.env.example` lists every variable with a placeholder; `.env.local` is
  git-ignored.

## Styling and accessibility

- Tailwind v4 tokens from `src/app/globals.css` (`bg-background`,
  `text-muted-foreground`); shadcn components used as-is; `cva` for
  variants; `cn` for merging. Arbitrary values need a comment.
- Native interactive elements; labels on every control; field errors
  linked with `aria-describedby` and `aria-invalid`; icon buttons carry
  `aria-label`; async regions carry `role="status"`.
- Focus visible; dialogs trap and return focus (shadcn does this).

## Testing

- vitest with jsdom and Testing Library. A server component is
  `await`ed, then rendered: `render(await HealthCard())`. `fetch` is
  stubbed with `vi.stubGlobal`; `next/headers` and `@/lib/auth` are mocked
  with `vi.mock` where an action needs them.
- Route handlers are called directly: `const res = await GET()`.
- Actions are called directly with a `FormData`; the form is tested with
  a fake action passed as a prop.
- Playwright runs against `next build` and `next start`. Server-side
  fetches cannot be mocked from the browser, so `API_URL` points at the
  app's own `/api` handlers in `playwright.config.ts`; a spec asserts on
  roles and visible text, never on `waitForTimeout`.
- Coverage floors are 80 percent on `src/` minus wiring (layout, page,
  loading, global-error, proxy). A bug fix ships with its test.
- A route handler that calls `connection()` mocks `next/server` in its
  unit test; the test has no live request.

## Performance and bundle

- Client bundle grows only when a file says `"use client"`. Next 16's
  build table no longer prints first-load JS; measure with Lighthouse or
  the bundle analyser when a route feels heavy.
- No barrel files. A feature exposes nothing through an `index.ts` that
  re-exports its modules; import the file that defines the symbol. For a
  library whose entry re-exports thousands of modules (icon sets, `lodash`,
  `date-fns`), list it in `experimental.optimizePackageImports` if Next
  does not already, or import its subpath.
- Heavy client dependencies load with `next/dynamic` in the component
  that uses them, with `ssr: false` only when they touch `window`.
- Third-party scripts through `next/script` with a `strategy`.

## Style

- Prettier and ESLint (`eslint-config-next` plus strict type-checked
  rules) decide style. Nothing is discussed in review that a tool decides.
- Default exports only where Next requires them (route files, config).
  Named exports everywhere else.
- No `any`, no non-null assertion, no `as` to silence the compiler. A
  type guard or a schema parse instead.
