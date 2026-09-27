# Next.js review checklist

For each item, either find the concrete failure or write "none found".

## Server and client boundary
- `"use client"` on a file that has no hook, event handler or browser
  API; a page or layout marked client for one interactive child.
- A function, class instance, Date or Map passed as a prop from a server
  to a client component (not serialisable).
- A whole API record passed to a client component that renders one or two
  of its fields; the same large value passed to several client children.
- A mutable module-level variable (`let`, a `Map`, an array) written
  during a render, an action or a route handler: shared across concurrent
  requests, so one user's data can reach another.
- A server-only module (`src/env.server.ts`, `src/lib/api.ts`, a database
  client) imported from a client component; a client hook used in a
  server component.
- `async` on a client component; `await` of a server component inside a
  client one.

## Server actions and route handlers
- An action that acts before `requireSession()`; an authorisation check by
  role only, not by resource ownership (IDOR); a tenant id taken from a
  hidden input or a `.bind` argument instead of the session.
- An exported function in a `"use server"` file that no form uses, or that
  takes a tenant id as a parameter: callable by anyone with any value.
- `requireSession()`, `redirect()` or `notFound()` inside a `try` whose
  `catch` returns an error state: the redirect is swallowed.
- A batch action that stops or throws on the first failure and does not
  say which items changed.
- An action that reads `formData.get(...)` without a Zod parse; a raw
  error or stack returned to the form.
- An action that talks to a database directly instead of the API, or that
  returns something other than a state object.
- A form posting to a route handler; a route handler called from a
  component; a probe `GET` without `await connection()` (prerendered at
  build, so it reports the build, not the process).
- A mutation that leaves a cached read stale: no `updateTag` in the
  action; `updateTag` called outside a server action; `revalidateTag`
  with one argument; a `router.refresh()` where a tag would do.

## Caching and data
- A `"use cache"` function without `cacheTag` (nothing can expire it) or
  without `cacheLife`; one that calls `cookies()` or `headers()` instead
  of taking the value as an argument; one that takes a non-serialisable
  argument.
- A route segment `dynamic`, `revalidate` or `fetchCache` export, an
  `unstable_cache`, or a fetch `next: { revalidate, tags }` option in an
  app on Cache Components.
- Data that must be live inside a `"use cache"` scope; data that may lag
  fetched on every request with no reason given.
- A request waterfall: two independent `await`s in sequence; a parent
  server component that awaits data before rendering children that fetch
  their own; a loop of `await`s over items that could run in `Promise.all`.
- A slow await at the top of a page with no `Suspense` boundary below it;
  a `Suspense` fallback without `role="status"`.

## Configuration and secrets
- `process.env` read outside `src/env.ts` and `src/env.server.ts`; a
  secret in a `NEXT_PUBLIC_` variable, in `next.config.ts`, in
  `.env.example` or in the bundle.
- A server variable with a default that hides a missing secret.
- `remotePatterns` widened to `**`; `poweredByHeader` turned on.

## Rendering and assets
- `<img>` instead of `next/image`; an image without `width` and `height`
  or `fill`; `priority` on every image.
- A font fetched from a network at build; a font loaded outside
  `next/font`.
- `error.tsx` without `reset`; `global-error.tsx` importing the app's
  layout or CSS; `not-found.tsx` missing.
- Metadata duplicated by hand in `<head>` instead of `metadata` or
  `generateMetadata`.

## Proxy
- A database call or a heavy import in `proxy.ts`; a new `middleware.ts`
  in a Next 16 app (deprecated; the export is `proxy`).
- An authorisation decision made only in the proxy.
- A matcher that includes `_next/static` or the image optimiser.

## Accessibility
- A `div` or `span` with `onClick`; a form control without a label; an
  icon-only button without `aria-label`; a field error not linked with
  `aria-describedby`.
- A `Link` used for an action, or a `button` used for navigation.
- A loading or result region without `role="status"` or `aria-live`.

## Styling
- An arbitrary Tailwind value without a comment; a colour or spacing
  literal outside the tokens; a shadcn component edited in
  `src/components/ui`.

## Bundle
- A barrel `index.ts` that re-exports a feature's modules, or an import
  through one; a large library imported from its entry point when it is
  neither in Next's `optimizePackageImports` defaults nor added to the
  config.
- A heavy client dependency imported at the top of a client component
  instead of through `next/dynamic` where it is used.

## Tests
- A bug fix without a reproducing test.
- A server component tested through a client render helper instead of
  `await`; a test with a real `fetch`; a Playwright spec that assumes
  `page.route` can mock a server-side fetch.
- A new route without an e2e spec covering its success path.

## Hygiene
- `eslint-disable` added; a lint rule loosened; a dependency added
  unasked; `pnpm-lock.yaml` edited by hand.
- Em dash in a comment or doc.
