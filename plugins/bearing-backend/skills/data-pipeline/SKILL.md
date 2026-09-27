---
name: data-pipeline
description: 'Data pipeline house rules (dbt models with tests, Airflow 3 DAGs, sqlfluff, partitioned backfills). Load before writing or changing dbt, Airflow or warehouse code. Use when asked for "dbt models", "a backfill".'
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
  with this skill. `bearing:new-repo` and `bearing:ci-pipeline` are suggestions for a
  repository without a Makefile or a pipeline, never prerequisites.

## When this skill is active

- Writing or changing `.sql`, `.yml` under `dbt/` or `.py` under `dags/`:
  apply `references/guidelines.md`. Read it once per session, then work.
- Reviewing a diff with models or DAGs: apply `references/review-checklist.md`
  and report every finding as severity (Critical, High, Medium, Low), `file:line`, the claim, a concrete failure scenario and the fix, then list what was checked and found clean and what was not reviewed.
- Scaffolding (`new-repo data-pipeline <Name>`): `templates/` holds the
  skeleton and configs; `bin/brg-scaffold` in the bearing plugin copies them. Do not hand-copy.
- Generating CI (`bearing:ci-pipeline`): `templates/.gitlab-ci.yml` is the source.

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
   same rows. Incremental models carry `unique_key`, read their window
   from `start_date` and `end_date` vars bounded on both sides on every
   build (the first, non-incremental one too), and delete the whole
   window before inserting (see Traps).
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
   `max_active_runs=1`, the scheduled DAG paused while it runs. A mart
   that holds history the source no longer has sets `full_refresh: false`
   in its config, so the flag cannot wipe it.
6. Secrets come from the environment only. `profiles.yml` is git-ignored;
   the example reads `env_var()`; a literal password anywhere is a finding.
7. DAG files are import-safe: no network, no warehouse, no `Variable.get`
   at module level. The processor imports them every few seconds.
8. `make check` = ruff format check, ruff and sqlfluff lint, `dbt parse`,
   DAG import check, pytest. CI runs the same target, then `dbt build`
   against Postgres.

## Traps a correct-looking pipeline hides

Read the source documentation (loader behaviour, landing times, retention,
how long a row can change) before writing SQL; most of these come from it.

- **Airflow 3 cron schedules have no interval.** `schedule="@daily"` or a
  cron string gives `CronTriggerTimetable`: `data_interval_start` equals
  `data_interval_end`, so a `[start, end)` window is empty and the run
  writes nothing, green. Use `CronDataIntervalTimetable("0 1 * * *",
  timezone="UTC")` (`airflow.timetables.interval`) when tasks read the
  interval, and test that the inferred interval has length.
- **Append or CDC loaders.** When the loader appends a row per change,
  staging keeps one row per id (the latest `_loaded_at`, with a tie-breaker
  if two can share it) and tests `unique` on the id. Filters on status and
  amounts apply to that current row, after deduplication. Check every
  staging model that reads an append table, not only the one you touch.
- **Late-changing facts need a lookback per source.** Each nightly run
  rebuilds as many days back as a row can still change (edit window,
  reversal window, late arrival), taken from that source's documentation.
  A lookback shared from another source is a bug when the windows differ.
- **The delete covers the window, not the batch.** delete+insert removes
  only keys present in the new batch: keyed on (day, merchant), a merchant
  whose rows all disappear keeps its old row; keyed on day, a day that
  becomes empty keeps its rows. Delete `[start_date, end_date)` first (a
  pre-hook, `templates/skeleton/dbt/macros/delete_window.sql`) or use
  microbatch, which replaces each batch's time range.
- **Retention bounds every rebuild.** When raw keeps N days and the mart
  keeps more, a window delete that reaches a day raw no longer holds in
  full erases or understates it. The default vars in `dbt_project.yml`
  (all of time) turn a plain `dbt run` or `make dbt-build` into exactly
  that; guard it (explicit vars required for history marts, or a check
  against the oldest complete day in raw) and set `full_refresh: false`.
  If retention cuts by one timestamp and the mart dates by another
  (requested vs succeeded), the oldest days raw holds are partial: say so.
  Never clamp the window with `now()` or `current_date`: a model's output
  must not depend on when it ran.
- **Backfill arithmetic, computed from the repository and today's date.**
  First affected day = the window start of the first bad run (the change
  date minus the lookback), not the change date. Oldest rebuildable day =
  the oldest day raw holds in full (today minus retention, plus one for the
  partly deleted day). Affected days older than that cannot be corrected
  from raw: list them and say what would fix them (a re-export) instead of
  backfilling them. Give the deadline: each remaining day falls out of raw
  one a day. Hand over the command with dates filled in and a read-only
  query that confirms the first affected day.
- **Schedules versus landing times.** A model must not run before its
  source lands. Tags set in `dbt_project.yml` are inherited, so a new mart
  under `marts/` joins `tag:daily` and the early run builds it; exclude it
  there and run it after landing, behind `dbt source freshness`.
- **Units and dates.** Money becomes integer minor units with `round`,
  never truncation; an event is dated by the timestamp the metric
  definition names, in UTC.
- **Microbatch (dbt 1.9+)** is the native form of all this for a new model:
  `incremental_strategy='microbatch'`, `event_time`, `batch_size='day'`,
  `lookback`, `begin`. Without `--event-time-start` and `--event-time-end`
  it batches relative to the wall clock, so the DAG passes the data
  interval. Do not migrate an existing model inside a fix.

## Verifying and reporting

- When dbt or Airflow is not installed, render the model SQL by hand and
  run it against a disposable Postgres you start yourself (a free port,
  removed after), with rows that exercise the traps above: an edited id,
  a status that changes after the fact, a group that disappears. If that
  is not possible, say the SQL was judged by reading only.
- The final message names each gate and whether it ran: `make check`,
  `dbt parse`, `dbt build`, sqlfluff, and the DAG import (say Airflow is
  not installed when it is not). It states how far back the data the
  change produces reaches, which days it cannot fix, and never reports
  figures or counts it did not compute.
- Problems seen outside the request (another model with the same defect,
  a destructive make target) are reported with the days they affect, and
  fixed only when they block the requested change.

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
  template keeps it false and backfills explicitly. `airflow backfill
  create` runs through the scheduler beside the scheduled runs: pause the
  DAG first when both write the same days.
- `AIRFLOW_HOME` is `.airflow/` in the repository (git-ignored) so the
  import check never writes `~/airflow`.
- `uv.lock` pins dbt and Airflow together; both move often. Run `uv lock`
  after touching `pyproject.toml`, never edit the lock.
