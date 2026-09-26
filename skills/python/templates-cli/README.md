# __REPO_NAME__

Python command-line tool (standard library argparse). `make help` lists every
command; `make check` is the gate.

## Run

```
make setup
make run ARGS="lines README.md"
uv run __REPO_SLUG__ --help
```

`make setup` installs the tool editable into `.venv`, so `uv run __REPO_SLUG__`
runs the working tree. `python -m app` does the same. `make build` writes the
wheel and sdist to `dist/`; `uv tool install dist/*.whl` installs it on a
machine.

Exit codes: 0 success, 1 the command failed (the reason on stderr), 2 a usage
error.

## Layout

See `AGENTS.md` and the `python` skill for the conventions. `src/app/cli.py`
parses arguments and dispatches to one handler per subcommand; handlers return
an exit code and raise `CommandError` for a failure the user can act on. Keep
logic that is more than argument handling in its own module under `src/app/`
and test it directly.
