# ADR-0003: Serve every asset from our own origin

Status: Accepted
Date: 2026-02-18

## Context

Several customers run Haulbook inside warehouse networks whose firewalls
allow our domain and nothing else. In January the tracking link rendered
without text for two of them because its fonts came from a third-party
CDN, and one customer's security review rejected any third-party request
from the app.

## Decision

Scripts, styles, fonts and images are bundled or served from our own
origin. Fonts come from npm packages (Fontsource) that Vite bundles. The
edge sets `Content-Security-Policy: default-src 'self'; font-src 'self'`
and index.html mirrors it for local runs.

## Consequences

No Google Fonts or other CDN links. A new typeface is added as a
Fontsource package (or a woff2 file under public/fonts) and goes through
the same licence check as any dependency.
