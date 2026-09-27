# support-console

The internal web console the support team uses to look up customers.
Vite, React 19, TypeScript, TanStack Query, React Router, Zustand, Zod, Tailwind.

## Run it

```
pnpm install
cp .env.example .env
pnpm dev          # http://localhost:5173, talks to the support API at VITE_API_BASE_URL
pnpm lint
pnpm typecheck
pnpm test
```

## Layout

- `src/app/` providers, routes and the UI store
- `src/lib/` the API client (`apiFetch`), env parsing, the query client
- `src/features/<feature>/` schemas, fetch functions, query hooks and screens
- `src/test/` test setup and the MSW handlers the tests share

The support API contract is in `docs/api.md`. Decisions are in `docs/adr/`.
