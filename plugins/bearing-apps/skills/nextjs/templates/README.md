# __REPO_NAME__

Next.js app (App Router). `make help` lists every command; `make check` is
the gate.

## Run

```
cp .env.example .env.local
make setup          # pnpm install (writes pnpm-lock.yaml; commit it), Playwright chromium, git hooks
make dev            # http://localhost:3000
```

`make check` prints one `<gate>: N ... checked` line per gate (format,
lint, typecheck, unit tests, dependency audit) and a final tally. A gate
whose tool is missing prints `SKIPPED` and the tally fails;
`BEARING_ALLOW_SKIP=1 make check` lets a laptop through and is never set in CI.
`make build` and `make test-e2e` (Playwright against the production build)
are CI jobs, not part of `check`.

## Layout

See `AGENTS.md` and the `nextjs` skill for the conventions. `src/app`
holds the routes (`layout`, `page`, `loading`, `error`, `global-error`,
`not-found`, `api/*/route.ts`), `src/features/<feature>` owns a domain
(schemas, server-side `api`, server actions in `actions.ts`, components),
`src/components/ui` is shadcn output, `src/lib` holds the API client, auth
and `cn`, `src/env.ts` (public) and `src/env.server.ts` (server-only)
parse the environment, `src/proxy.ts` adds the request id, `e2e/`
holds Playwright specs.

## Server and client

A file is a server component unless it starts with `"use client"`.
`HealthCard` fetches on the server at request time, inside a `Suspense`
boundary; `FeedbackForm` is a client component because it needs
`useActionState`, and its server action validates with Zod after
`requireSession`.

## Caching

`cacheComponents` is on in `next.config.ts` (Next 16). Nothing is cached
unless a function says `"use cache"` with `cacheLife` and `cacheTag`; a
server action that changes the data calls `updateTag`. `src/lib/api.ts`
and `src/features/health/api.ts` show the pattern. The Next docs for the
installed version are in `node_modules/next/dist/docs/`.

## Add a shadcn component

```
pnpm dlx shadcn@latest add dialog
```

`src/components/ui/button.tsx` is the example the generator produced; files
in that folder are not linted and are regenerated, not hand-edited.

## Image

```
docker build --build-arg NEXT_PUBLIC_APP_NAME="__REPO_NAME__" -t __REPO_SLUG__ .
docker run --rm -p 3000:3000 -e API_URL=http://api:8080 __REPO_SLUG__
```
