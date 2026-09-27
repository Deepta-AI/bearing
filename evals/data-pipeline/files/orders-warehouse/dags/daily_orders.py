"""Nightly orders pipeline: rebuild the orders marts for the last 30 days, then test them."""

from __future__ import annotations

import os
from datetime import timedelta

import pendulum
from airflow.providers.standard.operators.bash import BashOperator
from airflow.sdk import dag
from airflow.timetables.interval import CronDataIntervalTimetable

DBT_PROJECT_DIR = os.environ.get("DBT_PROJECT_DIR", "/app/dbt")
DBT_PROFILES_DIR = os.environ.get("DBT_PROFILES_DIR", "/app")
DBT = f"dbt --no-use-colors --project-dir {DBT_PROJECT_DIR} --profiles-dir {DBT_PROFILES_DIR}"

# The window, [start, end), rendered by Airflow from the run's data
# interval. It starts 30 days before the interval: merchants can edit an
# order for 30 days (docs/sources.md), so every run rebuilds the days an
# edit can still change.
LOOKBACK_DAYS = 30
WINDOW = (
    '--vars \'{"start_date": "{{ macros.ds_add(data_interval_start | ds, -%d) }}", '
    '"end_date": "{{ data_interval_end | ds }}"}\'' % LOOKBACK_DAYS
)


@dag(
    dag_id="daily_orders",
    description="dbt run and test for the orders marts, a 30 day window per run",
    # 01:00 UTC: raw.orders and raw.merchants are landed by 00:30 UTC. The
    # interval timetable gives each run the previous day as its data
    # interval (a plain cron string in Airflow 3 gives a zero-length one).
    schedule=CronDataIntervalTimetable("0 1 * * *", timezone="UTC"),
    start_date=pendulum.datetime(2026, 1, 1, tz="UTC"),
    catchup=False,
    dagrun_timeout=timedelta(hours=2),
    default_args={
        "owner": "data",
        "retries": 2,
        "retry_delay": timedelta(minutes=5),
    },
    tags=["dbt", "daily"],
)
def daily_orders() -> None:
    """Run the daily-tagged models for the interval, then test them."""
    dbt_run = BashOperator(
        task_id="dbt_run",
        bash_command=f"{DBT} run --select +tag:daily {WINDOW}",
    )
    dbt_test = BashOperator(
        task_id="dbt_test",
        bash_command=f"{DBT} test --select +tag:daily {WINDOW}",
    )
    dbt_run >> dbt_test


daily_orders()
