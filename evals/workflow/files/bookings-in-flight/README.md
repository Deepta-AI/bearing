# bookings-api

Books slots at partner clinics. Node 22, no dependencies.

## Working here

- One branch per ticket, `feature/<TICKET>-<slug>`, merged to `main` through a
  merge request on the team's GitLab.
- Each task keeps its shared record in `docs/progress/<TICKET>.md`, committed on
  the task branch; it reaches `main` when the branch is merged.
- Decisions live in `docs/adr/`.
- `make check` runs the tests.
