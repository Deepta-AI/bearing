# billing-console

Internal console where finance teams of each customer organisation see and
manage their invoices. Multi-tenant: every signed-in user belongs to one
organisation and must only ever see that organisation's data.

Next.js 16 App Router with Cache Components. Data comes from the ledger
API (docs/ledger-api.md); the console has no database.

    pnpm install && cp .env.example .env.local && pnpm dev

Checks: `pnpm lint`, `pnpm typecheck`, `pnpm test`, `pnpm build`.
