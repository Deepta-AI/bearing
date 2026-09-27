# patient-portal

The white-labelled patient portal: appointments, prescriptions and
messages. Each clinic group (a tenant) gets its own hostname, logo and
accent colours; everything else is the same product. React 18 with Vite.

## How tenants work

- `src/theme/registry.js` maps a hostname to a tenant and imports its
  theme from `src/theme/tenants/<name>.json`.
- `src/theme/applyTenant.js` turns that theme into CSS custom properties
  on `:root[data-tenant="<name>"]` (light) and
  `:root[data-tenant="<name>"][data-theme="dark"]` (dark), and sets the
  logo and display face. Only the roles in `ALLOWED_ROLES` are applied.
- Brand kits arrive from the clinic's agency in `config/tenants/` exactly
  as they were sent. They are input for a person setting up the tenant,
  not something the app reads.
- What a tenant may change is decided in
  `docs/adr/0004-tenant-theming-scope.md`.

## Commands

    make check    # node --test: theme and registry tests (no install needed)

`pnpm install` and `pnpm dev` need the network; CI runs the Vite build.
