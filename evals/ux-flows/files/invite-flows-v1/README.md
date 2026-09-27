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
revoking invites landed in CRW-81. The invite flows (v1) were reviewed on
18 Sep: `docs/design/flows/team-invites/flows.md`, review notes in
`docs/design/reviews/`. Screen design works from the flows and cites their
screen ids. CRW-93 carries the product feedback on v1
(`docs/product/CRW-93-v1-feedback.md`); support tickets are in `docs/support/`.
