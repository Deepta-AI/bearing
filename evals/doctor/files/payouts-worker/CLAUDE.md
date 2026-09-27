@AGENTS.md

# CLAUDE.md

Claude Code specifics for this repository; the standard is AGENTS.md above.

```
Repository:   payouts-worker (worker)
Stack:        python 3.12, pytest
Databases:    none (reads balances handed in by the scheduler)
Entrypoint:   src/payouts/batch.py
Run, test:    make test; gate: make check
Git host:     gitlab
Trunk:        main
```

Plan mode for anything over three files. On a third failed approach, stop
and say so.
