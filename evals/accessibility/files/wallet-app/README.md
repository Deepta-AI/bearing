# Pocketline mobile

Expo (SDK 52) app with Expo Router: balance, activity, send money, receipts
and settings. iOS and Android from one codebase.

    pnpm install
    pnpm start         # Expo dev server
    pnpm typecheck     # tsc --noEmit
    pnpm test          # jest-expo

The municipal payroll client needs an accessibility audit against WCAG 2.2 AA
(their procurement uses EN 301 549) before contract signature.

## Layout

- app/: screens (Expo Router file routes)
- src/components/: shared components
- src/theme.ts: colours and spacing
- docs/design/: copy from design
- docs/adr/: decisions
