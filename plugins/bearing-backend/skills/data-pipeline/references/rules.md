---
paths:
  - "dbt/**/*.sql"
  - "dbt/**/*.yml"
  - "dags/**/*.py"
  - "tests/**/*.py"
---

# Data pipeline rules (loaded when a model, schema file, DAG or test is touched)

- Idempotent per partition: a task for a data interval writes that interval
  only; incremental models carry `unique_key`, read `start_date` and
  `end_date` from vars bounded on both sides on every build, and delete the
  whole window first (delete+insert alone keeps groups that vanished).
- Append or CDC sources: staging keeps the latest row per id and tests
  `unique` on it; status filters apply after deduplication. Each source's
  nightly lookback covers how long its rows can still change.
- No rebuild reaches a day raw no longer holds in full; history marts set
  `full_refresh: false`. A model never reads `now()` or `current_date`.
- No `select *` in a model; explicit columns, explicit casts in staging,
  explicit schemas per layer (`raw`, `staging`, `intermediate`, `marts`).
- Layers point one way: staging reads sources or seeds, intermediate reads
  staging, marts read intermediate or staging. Prefixes `stg_`, `int_`,
  `dim_`, `fct_`.
- Every mart has yml with a description and `data_tests`: `unique` and
  `not_null` on the key, `accepted_values` on enumerations, `relationships`
  on foreign keys, an expectation on every measure.
- Backfill by partition (`make backfill`, `airflow backfill create`), oldest
  first, one active run, the scheduled DAG paused; never `--full-refresh` in
  production.
- Secrets only from the environment: `profiles.yml` is git-ignored and the
  example reads `env_var()`; a literal credential anywhere is a finding.
- DAG files are import-safe: no network, warehouse, `Variable.get` or
  `datetime.now()` at module level; the window comes from the run's
  `data_interval_start` and `data_interval_end`, and the schedule is an
  interval timetable (a cron string in Airflow 3 gives a zero-length one).
- Every DAG sets an owner, retries, `max_active_runs=1`, a timeout and
  tags; every task is a thin call to dbt or a typed operator.
- sqlfluff and ruff decide style; nothing a tool decides is discussed in
  review. `uv.lock` is committed and regenerated with `uv lock`.
- A change to a model ships with its tests; a bug fix ships with the test
  that reproduces it.
