# Payline Ops

The back-office console finance staff use to check vendor invoices and,
from next sprint, approve vendor payouts. React 19, Vite, TypeScript,
Tailwind v4 and shadcn/ui (`src/components/ui`, see `components.json`).

## Running

```
pnpm install      # not vendored; needs the network
pnpm dev          # http://127.0.0.1:5173
make check        # unit tests for src/lib (node --test, no install needed)
```

## Where things are

- `src/index.css`: the design tokens (light and dark). These are the
  source of truth for colour, radius and type; see ADR-0004.
- `src/components/app-shell.tsx`: sidebar and header every page sits in.
- `src/features/invoices/`: the invoices list, the pattern new screens follow.
- `src/api/`: typed clients for the Payline API. Money is always integer
  paise (`amount_paise`); format it with `formatINR` from `src/lib/format.ts`.
- `docs/product/PRD.md`: the payout approvals PRD.
- `docs/design/flows/payouts/flows.md`: the payout approval flows (screens,
  states, copy, navigation), signed off in the design review on 18 Sep.
