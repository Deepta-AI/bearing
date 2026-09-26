# __REPO_NAME__

Go service. `make help` lists every command; `make check` is the gate.

## Run

```
cp .env.example .env
make setup                  # tidies go.sum and tools/go.sum, installs the pinned tools into bin/tools
make db && make migrate
make dev
```

## Layout

See `AGENTS.md` and the `go` skill for the conventions. `cmd/api` wires,
`internal/httpapi` serves, `internal/<domain>` decides, `internal/store`
persists, `db/` migrates.
