# Basket

The customer app for Basket, a grocery delivery service. Expo SDK 57,
expo-router, TanStack Query for server data, Zustand for the session, Zod
for every API response. One codebase for iOS and Android.

## Running it

    pnpm install      # once; node_modules is not committed
    make dev          # expo start
    make check        # typecheck, lint, unit tests

`make check` needs `node_modules` (run `pnpm install` first).

## Layout

- `app/(auth)/` sign in. `app/(app)/` everything behind sign in; its
  `_layout.tsx` is the only auth gate.
- `app/(app)/(tabs)/` the bottom tabs: Shop and Account.
- `app/(app)/orders/` order detail.
- `src/features/<feature>/` api calls, schemas and hooks per feature.
- `src/lib/` the API client, query client, session store, secure store
  and money formatting.
- `docs/api.md` the Basket API as the app uses it. `docs/adr/` decisions.

## API notes

- Base URL comes from `EXPO_PUBLIC_API_URL` (see `.env.example`).
- Amounts are integer paise (`*_minor`); display them with `formatMoney`.
- Deep links use the `basket://` scheme (app.json).

## Releases

Store builds go through EAS (`eas.json`); the production profile sets the
public environment for the bundle. JavaScript-only fixes ship between
store releases as an EAS Update on the `production` channel; installed
binaries take updates published for their runtime version.
