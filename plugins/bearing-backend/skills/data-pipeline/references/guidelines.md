# Data pipeline guidelines

## Project shape

- `dbt/` is the dbt project; `dags/` holds the Airflow DAGs; `tests/` holds
  pytest. The dbt project name is `pipeline`, fixed, because a dbt name
  must be an identifier; the repository name lives in `pyproject.toml`.
- One DAG per pipeline (`dags/daily_orders.py`), named for what it
  produces. One model per file, named for its layer and grain.
- The runner image holds dbt and the project; Airflow is deployed on its
  own (managed service or chart). The DAG calls the image or the installed
  dbt; it never imports dbt as a library.

## Layers and naming

- `staging/stg_<source>.sql`: one model per raw table. Rename to
  snake_case, cast every column, lower-case strings that are compared,
  nothing else. Materialised as views in the `staging` schema.
- `intermediate/int_<concept>.sql`: joins and business logic that more
  than one mart needs. Views in `intermediate`; never read by a consumer.
- `marts/dim_<entity>.sql` and `marts/fct_<event>_<grain>.sql`: what
  consumers read. Tables in `marts`; facts are incremental by partition
  once they grow.
- Sources are declared once in `_sources.yml` with freshness; seeds are for
  small reference data only. The template ships seeds as stand-ins for the
  first source; replace them.
- Schemas come out as `raw`, `staging`, `intermediate`, `marts` through
  `macros/generate_schema_name.sql`; `target.schema` is only the fallback.

## SQL

- Explicit columns, always. `select *` hides schema drift and breaks the
  contract a mart makes with its readers.
- Every table has an alias and every column is qualified, so a lint or a
  reader can tell where a column came from.
- CTEs named for what they hold (`first_orders`, not `t1`), one
  transformation each, final `select` at the bottom.
- Money in minor units as integers; dates as `date`, timestamps with time
  zone; booleans as booleans, not `'Y'`.
- sqlfluff decides style (lower-case keywords, four-space indents, explicit
  aliases). `make lint` renders with the jinja templater and dbt builtins
  so it runs offline; `make lint-dbt` compiles through dbt where a
  warehouse is reachable. Nothing a tool decides is discussed in review.

## Incremental models and backfills

- `materialized='incremental'`, `unique_key` on the partition columns,
  `incremental_strategy='delete+insert'` on Postgres (merge on warehouses
  that have it), `on_schema_change='fail'` so a drift is a decision.
- The model reads its window from `var("start_date")` and
  `var("end_date")` (end exclusive). `dbt_project.yml` defaults them to
  the whole range so a plain `dbt run` still works; the DAG passes the
  run's data interval; `make backfill` passes an explicit range.
- Never `--full-refresh` in production. A schema change that needs a
  rebuild is a new model name plus a swap, or a backfill by partition
  from the earliest affected day.
- `is_incremental()` runs an introspective query at compile time. Prefer
  the explicit window, which parses and lints offline; use
  `is_incremental()` only where the window is not enough, and never to
  drop the upper bound on the first build (a first build that reads all of
  raw writes the partial current day).
- The window delete: `pre_hook="{{ delete_window('<date column>') }}"`
  (`macros/delete_window.sql`) clears `[start_date, end_date)` before the
  insert, so a group or a day that vanished loses its row.
- Lookback: the DAG widens the window backwards by as many days as the
  source's rows can still change; each source documents its own.
- A mart that keeps history older than raw's retention sets
  `full_refresh: false` and is never rebuilt with vars reaching before the
  oldest day raw holds in full.
- dbt 1.9+ microbatch (`event_time`, `batch_size='day'`, `lookback`,
  `begin`) replaces each day natively; the DAG passes
  `--event-time-start`/`--event-time-end` from the data interval.

## Tests and data quality

- Every model has a yml entry with a description; every mart column has
  one too (`persist_docs` writes them into the warehouse).
- Built-in tests: `unique` and `not_null` on keys, `accepted_values` on
  enumerations, `relationships` on foreign keys.
- Expectations on measures: `expect_column_values_to_be_between` in
  `dbt/tests/generic/` is written in-house so the project has no package
  dependency to start. Add `dbt-expectations` (or `dbt_utils`) in
  `packages.yml` when a second expectation is needed, run `dbt deps` in
  `make setup`, and delete the in-house copy.
- A test's severity is `error` unless a written reason says why a warning
  is enough. A failing test blocks the DAG (`dbt_test` after `dbt_run`).
- Freshness on every source, checked by a DAG task where staleness would
  mislead readers.

## Airflow DAGs

- Airflow 3: `from airflow.sdk import dag, task`; operators from
  `airflow.providers.standard`. Time-zone-aware `start_date` (pendulum).
- Import-safe: the processor imports every file every few seconds. Nothing
  at module level touches the network, the warehouse, `Variable`,
  `Connection` or the clock. Paths and flags come from `os.environ` with
  defaults.
- Every DAG: `owner`, `retries` with a `retry_delay`, `max_active_runs=1`
  when tasks write partitions, `dagrun_timeout`, `tags`, `catchup=False`
  with backfills run explicitly.
- Tasks are thin: a `BashOperator` calling dbt with `--select` and the
  window `--vars`, or a typed operator. Business logic lives in dbt, not
  in Python inside the DAG.
- The window is always `data_interval_start` and `data_interval_end`
  rendered by Airflow, never computed from `now()`.
- Schedule with `CronDataIntervalTimetable` (or `DeltaDataIntervalTimetable`)
  when tasks read the data interval: in Airflow 3 a cron string or preset
  is a `CronTriggerTimetable` with a zero-length interval.
- Schedule after the sources land; a source landing later than the rest
  gets its own DAG or a later task behind `dbt source freshness`, and its
  models are excluded from the early run (tags are inherited from
  `dbt_project.yml`).
- Backfill: pause the DAG, then `airflow backfill create --dag-id <id>
  --from-date --to-date --max-active-runs 1`, oldest first, watched to
  completion, then unpause.

## Lineage and docs

- `dbt docs generate` writes `dbt/target/manifest.json` (the graph) and
  `catalog.json` (the columns); CI keeps them as artifacts. The manifest
  is the input for any lineage tool.
- OpenLineage: add `apache-airflow-providers-openlineage` and set
  `OPENLINEAGE_URL` to emit run events; dbt emits the same through
  `dbt-ol run`. Both are optional until a catalogue asks for them.

## Configuration and secrets

- `profiles.yml.example` reads every value with `env_var()`; `make setup`
  copies it to the git-ignored `profiles.yml`. The `prod` target has no
  defaults, so a missing variable fails loudly.
- `.env.example` lists every `DBT_*` variable with a placeholder. A real
  password never appears in the repository, a DAG, a log or a test.
- The warehouse adapter is a decision (`tech-decision`, analytics store):
  change the dependency, the profile `type` and the incremental strategy
  together, in one ADR.

## Testing (pytest)

- `tests/dag_import_check.py` is the gate: every DAG file imports, with
  the count. `tests/test_dags.py` checks owner, retries, ordering and that
  the window comes from the run. `tests/test_dbt_layout.py` enforces the
  layers, prefixes, `select *` and mart tests, so a rule holds without a
  reviewer.
- Warehouse tests are `@pytest.mark.warehouse` and run through `make
  dbt-test` in CI against Postgres, never in `make test`.
- A bug in a model ships with a dbt test that would have caught it; a bug
  in a DAG ships with a pytest.

## Style

- ruff and sqlfluff decide style. Docstrings on every DAG file and public
  function, one line, saying what it is for. Comments explain why.
- yml files are named `_<layer>.yml` and sit beside their models.
