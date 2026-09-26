# __REPO_NAME__

Go command-line tool. `make help` lists every command; `make check` is the
gate.

## Run

```
make setup                  # tidies go.mod and tools/go.sum, installs the pinned tools into bin/tools
make run ARGS="greet --name Ada"
make build && ./bin/__REPO_SLUG__ --version
```

## Layout

See `AGENTS.md` and the `go` skill for the conventions.
`cmd/__REPO_SLUG__` only hands the arguments and the output streams to
`internal/cli`, which parses flags, dispatches subcommands and returns the
exit code: 0 done, 1 the command failed, 2 the command line was wrong. Add a
subcommand to the `commands` table in `internal/cli/cli.go` and a case to its
table test. The module uses the standard library only, so there is no
`go.sum` until the first dependency arrives.
