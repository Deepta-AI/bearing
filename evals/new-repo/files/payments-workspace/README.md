# payments-workspace

The payments group's workspace: the list of our repositories, the shared
conventions, and the group's architecture decisions. Clone this, run
`make clone`, and every repository in `repos.yaml` lands beside it.

- `repos.yaml`: every repository the group owns, with its kind, language,
  port and owners. `make check` validates it.
- `docs/service-conventions.md`: how a payments repository is set up.
- `docs/adr/`: group-wide decisions.

## Ports

Payments services use 8100 to 8199. Next free port: 8103.

## Finance exports

Finance drops bank payout exports into `finance-drop/` when they need a lead to
look at one. That folder is ignored here on purpose; see the data handling
section of the conventions before touching those files.
