# support-console

The internal web console the support team uses to look up customer orders.
Vite, React 19, TypeScript, TanStack Query, React Router, Zod, Tailwind.

## Run it

```
pnpm install
cp .env.example .env
pnpm dev          # http://localhost:5173, talks to the orders API at VITE_API_BASE_URL
pnpm lint
pnpm typecheck
pnpm test
```

## Layout

- `src/app/` providers and routes
- `src/lib/` the API client (`apiFetch`), env parsing, the query client
- `src/features/orders/` schemas, fetch functions, query hooks and the orders screens
- `src/test/` test setup and the MSW handlers the tests share

## Links into the console

The helpdesk's customer sidebar has had an "Orders" button since API v1.5. It
opens `/orders?q=<the customer's email, URL-encoded>` in the console so an agent
lands on that customer's orders. The console does not read the parameter yet, so
today the button just opens the unfiltered list.

The orders API contract is in `docs/api.md`; it is maintained by the backend team
and is the source of truth for query parameters and enum values.
