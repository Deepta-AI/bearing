"""Daily orders pipeline: one dbt run per day partition, then the dbt tests.

Every task is idempotent for its data interval: the dbt marts are
incremental with delete+insert on the partition key, so re-running a day
overwrites that day and nothing else. Nothing here touches the network at
import time; the DAG processor imports this file every few seconds.

Backfill (Airflow 3 CLI), one run per day in the range, oldest first:

    airflow backfill create --dag-id daily_orders \
        --from-date 2026-01-01 --to-date 2026-01-31 --max-active-runs 1

`make backfill start=2026-01-01 end=2026-02-01` runs the same window through
dbt directly when the orchestrator is not involved.
"""

from __future__ import annotations

import os
from datetime import timedelta

import pendulum
from airflow.providers.standard.operators.bash import BashOperator
from airflow.sdk import dag

# Paths come from the environment so the same file runs on a laptop
# (./dbt, ./profiles.yml) and in the runner image (/app/dbt, /app).
DBT_PROJECT_DIR = os.environ.get("DBT_PROJECT_DIR", "/app/dbt")
DBT_PROFILES_DIR = os.environ.get("DBT_PROFILES_DIR", "/app")
DBT = "dbt --no-use-colors"
DBT_DIRS = f"--project-dir {DBT_PROJECT_DIR} --profiles-dir {DBT_PROFILES_DIR}"

# The window is the data interval of the run: [start, end), rendered by
# Airflow at execution time, never computed from "now".
PARTITION_VARS = (
    '--vars \'{"start_date": "{{ data_interval_start | ds }}", '
    '"end_date": "{{ data_interval_end | ds }}"}\''
)


@dag(
    dag_id="daily_orders",
    description="dbt run and test for the orders marts, one day per run",
    schedule="@daily",
    start_date=pendulum.datetime(2026, 1, 1, tz="UTC"),
    catchup=False,
    max_active_runs=1,
    dagrun_timeout=timedelta(hours=2),
    default_args={
        "owner": "data",
        "retries": 2,
        "retry_delay": timedelta(minutes=5),
        "depends_on_past": False,
    },
    tags=["dbt", "daily"],
)
def daily_orders() -> None:
    """Run the daily-tagged models for the interval, then test them."""
    dbt_run = BashOperator(
        task_id="dbt_run",
        bash_command=f"{DBT} run --select tag:daily {PARTITION_VARS} {DBT_DIRS}",
    )
    dbt_test = BashOperator(
        task_id="dbt_test",
        bash_command=f"{DBT} test --select tag:daily {PARTITION_VARS} {DBT_DIRS}",
    )
    dbt_run >> dbt_test


daily_orders()
