# data-pipeline: the repository layout

Read when you place a new model, test, macro or DAG.

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
