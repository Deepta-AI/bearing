---
name: data-pipeline
description: 'Conventions for data pipelines: dbt-core models with tests, Airflow 3 DAGs, sqlfluff, ruff, pytest, uv, partitioned backfills. Use when writing, reviewing or scaffolding "dbt models", "an Airflow DAG" or "a backfill".'
allowed-tools: Read, Grep, Glob, Bash(uv run dbt:*), Bash(uv run sqlfluff:*), Bash(uv run ruff:*), Bash(uv run pytest:*), Bash(make:*)
---

# data-pipeline

The data stack on this standard: Python 3.12 with uv, dbt-core 1.10 or
newer on `dbt-postgres` (the adapter is the tech-decision choice under the
analytics-store key; BigQuery, Snowflake and ClickHouse swap the adapter
and the profile `type`), Apache Airflow 3 DAGs with idempotent, partitioned
tasks, dbt data tests plus an in-house expectation-style generic test,
sqlfluff with the dbt templater, ruff, pytest over DAG structure and layout
rules, and lineage from `dbt docs generate`.

## Inputs

- Source files: the repository as it is; no scaffold is needed. A
  different layout is handled under "On a foreign layout".
- Gate: `make check` when a Makefile has that target; else the native
  commands under Commands, one by one.
- `references/guidelines.md` and `references/review-checklist.md` ship
  with this skill. `new-repo` and `ci-pipeline` are suggestions for a
  repository without a Makefile or a pipeline, never prerequisites.

## When this skill is active

- Writing or changing `.sql`, `.yml` under `dbt/` or `.py` under `dags/`:
  apply `references/guidelines.md`. Read it once per session, then work.
- Reviewing a diff with models or DAGs: apply `references/review-checklist.md`
  and report in the reviewer format.
- Scaffolding (`new-repo data-pipeline <Name>`): `templates/` holds the
  skeleton and configs; `bin/brg-scaffold` copies them. Do not hand-copy.
- Generating CI (`ci-pipeline`): `templates/.gitlab-ci.yml` is the source.

## Layout

```
dbt/dbt_project.yml        project (name `pipeline`), layer defaults, the partition vars
dbt/models/staging/        stg_<source>: one per raw table; rename, cast, nothing else
dbt/models/intermediate/   int_<concept>: joins and business logic; never queried directly
dbt/models/marts/          dim_ and fct_: what consumers read; every column tested
dbt/models/**/_<layer>.yml descriptions and data_tests beside the models
dbt/seeds/                 small reference data; example rows stand in for the source
dbt/tests/generic/         in-house generic tests (expectation style)
dbt/macros/                generate_schema_name and any shared SQL
dags/<pipeline>.py         one Airflow DAG per pipeline; import-safe, partitioned tasks
tests/                     pytest: DAG structure, layout rules; dag_import_check.py
profiles.yml.example       every value from DBT_* env vars; copied to profiles.yml by setup
Makefile                   the only entry point: help setup dev check fix test doctor
```

## On a foreign layout

Hard rules anywhere: 1, 2, 3, 5 (in whatever test framework the project
has), 6 and 8. Advisory: the directory layout, the dbt project location,
Airflow (Dagster or Prefect keep their own DAG shape), sqlfluff and the
Makefile targets: use the orchestrator, warehouse and lint the repository
already has; propose a switch in an ADR, never inside a feature change.
Say which rule was relaxed and why.

## Rules that matter most

1. Every task is idempotent for its partition. A run for a date interval
   writes that interval and nothing else, and running it twice leaves the
   same rows. Incremental models carry `unique_key` and read their window
   from `start_date` and `end_date` vars.
2. No `select *` in a model. Every column is named, every staging model
   casts and renames explicitly, every mart declares its columns in yml.
3. Three layers, one direction: staging reads sources or seeds,
   intermediate reads staging, marts read intermediate or staging. A mart
   reading a raw table is a finding.
4. Tests on every mart: `unique` and `not_null` on the key, `accepted_values`
   on enumerations, `relationships` on foreign keys, an expectation on
   every measure. `tests/test_dbt_layout.py` fails a mart without them.
5. Backfills go by partition, never by `--full-refresh` in production:
   `make backfill start= end=` or `airflow backfill create`, oldest first,
   `max_active_runs=1`.
6. Secrets come from the environment only. `profiles.yml` is git-ignored;
   the example reads `env_var()`; a literal password anywhere is a finding.
7. DAG files are import-safe: no network, no warehouse, no `Variable.get`
   at module level. The processor imports them every few seconds.
8. `make check` = ruff format check, ruff and sqlfluff lint, `dbt parse`,
   DAG import check, pytest. CI runs the same target, then `dbt build`
   against Postgres.

## Commands

Each target is used when the Makefile has it; the command after the
colon is the native form (`uv run <cmd>`, or the repository's own runner).

```
make setup         # uv sync (creates .venv and uv.lock), profiles.yml, git hooks
make check         # ruff format --check ; ruff check + sqlfluff lint ; dbt parse ; DAG import ; pytest
make fix           # ruff format ; ruff check --fix ; sqlfluff fix
make dbt-build     # dbt seed, run, test against DBT_* (needs make db)
make backfill start=2026-01-01 end=2026-02-01   # dbt run and test for the window, by partition
make dbt-docs      # dbt docs generate: dbt/target/manifest.json is the lineage
make airflow       # airflow standalone on :8080 (development only)
```

## Gotchas

- `dbt parse` needs a profile to know the adapter, even though it never
  connects. `make setup` copies `profiles.yml.example` to `profiles.yml`;
  a missing profile fails the gate with that instruction, never silently.
- sqlfluff's dbt templater, with dbt 1.8 or newer, opens a warehouse
  connection to fill dbt's relation cache, so it cannot run offline.
  `make lint` uses the jinja templater with `apply_dbt_builtins` (ref,
  source, config and var resolve without dbt); `make lint-dbt` runs the
  dbt templater in the CI job that has Postgres.
- The dbt project name is `pipeline` (a dbt name must be an identifier);
  the repository name lives in `pyproject.toml`. Schemas come out as
  `raw`, `staging`, `intermediate`, `marts` through the
  `generate_schema_name` macro, not `<target>_<custom>`.
- Airflow 3: DAGs import from `airflow.sdk`, operators from
  `airflow.providers.standard`, and `catchup` defaults to false. The
  template keeps it false and backfills explicitly.
- `AIRFLOW_HOME` is `.airflow/` in the repository (git-ignored) so the
  import check never writes `~/airflow`.
- `uv.lock` pins dbt and Airflow together; both move often. Run `uv lock`
  after touching `pyproject.toml`, never edit the lock.
