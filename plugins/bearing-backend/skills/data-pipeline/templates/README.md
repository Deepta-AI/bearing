# __REPO_NAME__

Data pipeline (dbt on Postgres, orchestrated by Airflow 3). `make help` lists
every command; `make check` is the gate.

## Run

```
cp .env.example .env
make setup          # uv sync (writes uv.lock; commit it), profiles.yml from the example, git hooks
make db             # Postgres in Docker
make dbt-build      # seed, run, test against it
make airflow        # Airflow standalone on http://localhost:8080 (development only)
```

`make check` prints one `<gate>: N ... checked` line per gate (format, lint
with sqlfluff, `dbt parse` with the model count, DAG import with the file
count, pytest) and a final tally. A gate whose tool is missing prints
`SKIPPED` and the tally fails; `BEARING_ALLOW_SKIP=1 make check` lets a laptop
through and is never set in CI. `make dbt-run`, `make dbt-test` and
`make backfill` need a warehouse and are CI jobs, not part of `check`.

## Layout

See `AGENTS.md` and the `data-pipeline` skill for the conventions. `dbt/` is the
dbt project (`models/staging`, `models/intermediate`, `models/marts`,
`seeds`, `tests/generic`, `macros`), `dags/` holds the Airflow DAGs,
`tests/` holds pytest over DAG structure and layout rules,
`profiles.yml.example` reads every connection value from `DBT_*` variables.

## Backfill

```
make backfill start=2026-01-01 end=2026-02-01     # dbt directly, end exclusive
airflow backfill create --dag-id daily_orders --from-date 2026-01-01 --to-date 2026-01-31
```

Both rebuild the incremental marts by partition. Never `--full-refresh` in
production.

## Lineage

`make dbt-docs` writes `dbt/target/manifest.json` and `catalog.json`; the
manifest is the lineage graph. To emit OpenLineage events from Airflow, add
`apache-airflow-providers-openlineage` and point `OPENLINEAGE_URL` at the
collector; dbt emits the same through `dbt-ol run`.

## Image

```
docker build -t __REPO_SLUG__ .
docker run --rm --env-file .env __REPO_SLUG__ run --select tag:daily
```
