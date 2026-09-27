# paygate

Card payment capture and refunds for the storefront. Go 1.25, standard
library only.

- Build and test: `make check`.
- Tracker: none. We do not use ticket ids. Commits and tests name the story
  they serve by its backlog id, for example `US-02-001`.
- Backlog: docs/product/backlog.md. Decisions: docs/adr.
- Work happens on feature branches cut from `main`; one MR per branch.
