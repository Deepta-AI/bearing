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
  `end_date` from vars, and use `delete+insert` (or merge) on the key.
- No `select *` in a model; explicit columns, explicit casts in staging,
  explicit schemas per layer (`raw`, `staging`, `intermediate`, `marts`).
- Layers point one way: staging reads sources or seeds, intermediate reads
  staging, marts read intermediate or staging. Prefixes `stg_`, `int_`,
  `dim_`, `fct_`.
- Every mart has yml with a description and `data_tests`: `unique` and
  `not_null` on the key, `accepted_values` on enumerations, `relationships`
  on foreign keys, an expectation on every measure.
- Backfill by partition (`make backfill`, `airflow backfill create`), oldest
  first, one active run; never `--full-refresh` in production.
- Secrets only from the environment: `profiles.yml` is git-ignored and the
  example reads `env_var()`; a literal credential anywhere is a finding.
- DAG files are import-safe: no network, warehouse, `Variable.get` or
  `datetime.now()` at module level; the window comes from the run's
  `data_interval_start` and `data_interval_end`.
- Every DAG sets an owner, retries, `max_active_runs=1`, a timeout and
  tags; every task is a thin call to dbt or a typed operator.
- sqlfluff and ruff decide style; nothing a tool decides is discussed in
  review. `uv.lock` is committed and regenerated with `uv lock`.
- A change to a model ships with its tests; a bug fix ships with the test
  that reproduces it.
