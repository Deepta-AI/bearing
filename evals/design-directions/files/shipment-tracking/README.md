# Haulbook web

Haulbook is used by dispatchers at small freight forwarders to book
part loads with regional carriers and follow each shipment to delivery.
Dispatchers keep it open all day on a desktop beside the phone; drivers
and warehouse leads open tracking links on their phones in the yard.

Stack: React 19, Vite, Tailwind CSS 4 and shadcn/ui (docs/adr/0001).
All assets are served from our own origin (docs/adr/0003).

## Run

    pnpm install
    pnpm dev

The theme toggle in the header sets light or dark and remembers it;
see src/theme.tsx.

## Screens

- `/shipments` list of open shipments
- `/shipments/:id` tracking for one shipment (new in 0.9, not yet
  released; the look is still open)
