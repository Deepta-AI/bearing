# shop-site

The shop's marketing site: Next.js with the App Router, static pages.

## Working here

- Branches: `feature/<ID>-<PascalName>` from `main`; there is no develop.
  Merge requests target `main`, which deploys on merge.
- Gate: `make check`. Offline it runs `scripts/check.sh`; CI also runs the
  type check and `next build`.
- Tasks are tracked as `WEB-<n>`.
