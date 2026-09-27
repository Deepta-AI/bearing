# Clinic Desk

Front-desk web app for outpatient clinics: today's appointments, check-in,
no-show marking. React 18, Vite, Tailwind CSS 3 and shadcn/ui.

## Develop

    npm install
    npm run dev

`make check` runs the unit tests.

## Where things live

- `DESIGN.md`: the visual direction agreed with the clinic group. The
  clinic group's operations lead owns it; changes to it go through them,
  not through a code change.
- `src/components/ui`: shadcn/ui components (generated, then owned by us).
- `src/index.css`: the theme variables the components read.
- `docs/adr`: decisions.
