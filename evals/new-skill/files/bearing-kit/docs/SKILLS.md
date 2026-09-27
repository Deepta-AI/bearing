# Skills

The table is generated from each skill's frontmatter by `make docs`.

<!-- skills:start -->
| Skill | Plugin | What it does |
|---|---|---|
| `react-native` | bearing-apps | React Native house rules: Expo, TypeScript strict, expo-router, React Query and Jest tests. |
| `go` | bearing-backend | Go house rules for services: net/http mux, pgx, sqlc, slog, table-driven and httptest tests, and a route-auth check. |
| `python` | bearing-backend | Python service house rules: FastAPI, Pydantic v2, SQLAlchemy 2, uv, ruff and pytest. |
| `adr` | bearing | Writes an architecture decision record in docs/adr with context, options and consequences, Proposed until someone accepts it. |
| `release` | bearing | Prepares a release from main: next version from the latest tag, changelog, release branch and the printed commands to publish it. |
| `runbook` | bearing | Writes an operational runbook for one service from its code and config: start, stop, health, alerts and recovery steps. |
<!-- skills:end -->

## Notes

- `release` prepares; you publish. It prints the push and tag commands.
- `go` ships `route-auth-go.py`, which the skill runs before finishing.
