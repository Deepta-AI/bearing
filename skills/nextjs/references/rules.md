---
paths:
  - "src/**/*.ts"
  - "src/**/*.tsx"
  - "next.config.ts"
---

# Next.js rules (loaded when a .ts or .tsx file under src is touched)

- In client components, server data lives in the fetching layer's cache only;
  never copy it into `useState` or a store, and never derive state in a
  `useEffect`: compute it during render.
- Server components by default; `"use client"` only for a hook, an event
  handler or a browser API, and as low in the tree as possible. Never pass
  a function or a class instance from a server to a client component.
- Every server action: `requireSession()` first, then `safeParse` of the
  input against a Zod schema, then the work through the API; return a
  state object, never throw the raw error.
- Server values only through `src/env.server.ts` (`server-only`); public
  values only through `src/env.ts` as `NEXT_PUBLIC_`; nothing else reads
  `process.env`.
- Cache Components: reads are request-time unless a feature function says
  `"use cache"` with `cacheLife` and `cacheTag`; actions call `updateTag`,
  route handlers `revalidateTag(tag, "max")`. No `dynamic`, `revalidate`,
  `fetchCache` segment config, no `unstable_cache`.
- Independent reads start together (`Promise.all`, sibling async
  components); no `await` chain for reads that do not depend on each other.
- No mutable module-level state on the server: request data travels as
  arguments and props. Client props carry the fields the client renders,
  not whole records. No barrel `index.ts` re-exports.
- Route handlers for machines (probes, webhooks), server actions for
  forms; a probe calls `await connection()` so it is never prerendered.
- Slow data under `Suspense` with a `role="status"` fallback; `loading.tsx`
  per route; `error.tsx` with `reset`; `global-error.tsx` self-contained.
- Zod at every boundary (API, forms, search params, env); types are
  `z.infer`. No `any`, `!` or silencing `as`.
- `next/image` with width and height (or `fill`), `next/font/local` with
  a committed font; no `<img>`, no font fetched at build.
- `proxy.ts` (Next 16's middleware, Node.js runtime): headers, redirects,
  rewrites only; no database, no authorisation that a page or action does
  not repeat.
- Native interactive elements, labels on every control, `aria-label` on
  icon buttons, `aria-describedby` on field errors, `role="status"` on
  async regions.
- Tests: `await` a server component then render it; Testing Library by
  role; `fetch` stubbed; Playwright against `next build`. A bug fix ships
  with its test. No `eslint-disable` without a task id.
