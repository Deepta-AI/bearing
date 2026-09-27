# payments-api

Takes card payments for merchant accounts and exposes them to the support
console. Fastify 5 with Zod schemas, Drizzle on Postgres, vitest.

    make setup    # pnpm install --frozen-lockfile
    make check    # prettier, eslint, tsc, vitest (units need no database)
    make migrate  # release job only, see docs/adr/0002

Every request is authenticated by the gateway, which forwards the merchant
account id in `x-account-id` and the caller's bearer token in `authorization`;
src/app.ts puts the account on `request.accountId`. Every query is scoped to
that account.

Production runs 3 replicas behind the gateway (deploy is outside this repo).
