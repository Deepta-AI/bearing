# go: the repository layout

Read when you place a new handler, service, repository, migration or query file.

```
cmd/api/main.go           wiring only: config, logger, db, server, signals
internal/config/          env parsing with defaults and validation
internal/httpapi/         handlers, middleware, routes (one file per resource)
internal/<domain>/        services: business rules, no SQL, no HTTP types
internal/store/           sqlc output plus hand-written repositories
db/migrations/            goose migrations, NNNN_name.sql with Up and Down
db/queries/               sqlc query files
tools/go.mod              developer tools pinned with the tool directive
Makefile                  the only entry point: help setup dev check fix test doctor
```
