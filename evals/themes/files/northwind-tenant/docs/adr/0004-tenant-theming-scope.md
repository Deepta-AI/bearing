# ADR 0004: What a tenant theme may change

Status: Accepted (2026-03-11)

## Context

Clinic groups want the portal to look like theirs. Agencies send brand
kits with far more in them than colours: fonts from font services,
logos on their CDNs, analytics tags, custom CSS. The portal shows
health information, and our data processing agreements promise that a
patient's browser talks to no third party while using it.

## Decision

A tenant theme may set only:

1. The accent family: `accent`, `accent-hover`, `accent-active`,
   `on-accent`, `accent-subtle`, `focus`, `link`, for light AND dark.
   Surfaces, text colours, status colours, spacing, radius and the body
   face stay the product's.
2. A logo: an SVG we host under `public/assets/tenants/<name>/`, or no
   logo (the display name is shown as a wordmark).
3. A display face for headings, from the self-hosted faces in
   `src/styles/fonts.css`.

Nothing in a theme may cause a request to another origin: no font
service, no logo or image URL on another host, no scripts or tags. The
CSP in `index.html` enforces this in the browser and must not be
widened for a tenant.

Every tenant must keep the product's accessibility bar (WCAG 2.1 AA) in
both modes: `on-accent` on `accent`, `accent-hover` and `accent-active`
at 4.5:1; `link` on `bg` and `surface` at 4.5:1; `accent` and `focus`
against `bg` and `surface` at 3:1. Where a brand colour cannot meet
this, we use a darker or lighter step of the same hue and tell the
tenant why.

## Consequences

Setting up a tenant is a code change reviewed like any other. Brand
kits in `config/tenants/` are kept as received for reference and are
never loaded by the app.
