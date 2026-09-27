# Contributing

## Branches

- `main` is the only long-lived branch; every merge request targets it.
- Branch names carry the Jira key: `feat/SHOP-<n>-<slug>` or
  `fix/SHOP-<n>-<slug>`.
- Commit subjects start with the key of the ticket the commit belongs to.

## Ticket statuses (Jira project SHOP)

To Do -> In Progress -> In Review -> Done

- **In Progress** when the branch is created.
- **In Review** when the merge request is opened. Link the merge request and
  the branch's commits on the ticket.
- **Done** only after the merge request is merged to `main` and the change is
  deployed to production. Nobody moves a ticket to Done before that, including
  the author.

## Tests

Test names carry the id of the test case they cover from
`docs/testing/test-cases.md` (for example `TC-031`).
