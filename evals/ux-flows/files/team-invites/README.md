# Crewbook

Shift scheduling for small teams. One workspace per company; people in a
workspace are members with the role `admin` or `member`.

- API: `src/server/` (plain `node:http`, in-memory store for now).
- Web: `src/web/` renders pages as HTML strings; `src/web/routes.js` is the
  list of client routes.
- Plans: Starter (5 seats, free) and Pro (billed per seat). See
  `src/server/plans.js`.
- Product backlog: `docs/product/backlog.md`. Decisions: `docs/adr/`.
  Analytics events: `docs/analytics/EVENT_SHEET.md`.

## Run

```
make check    # node --test, no dependencies
npm start     # API on :4100
```

## Current work

CRW-88: team invites (epic E-7). The API side of creating, listing and
revoking invites landed in CRW-81; the invite UI and the acceptance path
are next, and design wants the flows first.
