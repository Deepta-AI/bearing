@AGENTS.md

# CLAUDE.md

Claude Code specifics for this repository; the standard is AGENTS.md above.

```
Repository:   ledger-web (service)
Stack:        node (plain node:http, node:test)
Databases:    __DATABASES__
Entrypoint:   __ENTRYPOINT__
Run, test:    make dev, make test; gate: make check
Git host:     github
Trunk:        main
```

Plan mode for anything over three files or touching a schema. On a third
failed approach, stop and say so.

## Things the agent gets wrong in this repository

- Amounts are integer paise, never floats.
