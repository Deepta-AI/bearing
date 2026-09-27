---
name: python
description: 'Python service house rules: FastAPI, Pydantic v2, SQLAlchemy 2, uv, ruff and pytest. Use when asked for "a FastAPI endpoint", "a new Python service" or changing any Python service code.'
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(uv run pytest:*), Bash(uv run ruff:*), Bash(make check:*)
---

# python

Conventions for Python services built with FastAPI.

## Inputs

- Project: `pyproject.toml` at the repository root; if several, the one
  named in the request.

## Steps

1. One `APIRouter` per resource under `app/routers/`, included in
   `app/main.py`.
2. Auth is attached to the router, not repeated on each endpoint:
   `router = APIRouter(prefix="/orders", dependencies=[Depends(require_user)])`.
   A router that mixes public and private endpoints puts
   `Depends(require_user)` (or `Security(...)`) on each private endpoint
   instead. `app.include_router(router, dependencies=[...])` also counts.
3. Pydantic v2 models for every request and response body.
4. pytest with `httpx.AsyncClient` for endpoint tests.

## Output contract

```
Files: <paths>   pytest: N passed | not run   ruff: clean | N findings
```

## Gotchas

- A dependency that only reads a header without rejecting the request is
  not auth.
