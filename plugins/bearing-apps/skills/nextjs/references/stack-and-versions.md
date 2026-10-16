# nextjs: the stack, Next versus React, and version-specific rules

Read when you choose between Next and React, or the repository pins Next 15, Zod 3 or no cacheComponents.

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
