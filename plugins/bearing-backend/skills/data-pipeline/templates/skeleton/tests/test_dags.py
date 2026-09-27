"""Every DAG imports, is owned, retries, and reads its window from the run."""

from __future__ import annotations

import pendulum
import pytest


def test_every_dag_file_imports(dagbag) -> None:
    assert dagbag.import_errors == {}
    assert len(dagbag.dags) >= 1


def test_every_dag_has_owner_retries_and_tags(dagbag) -> None:
    for dag_id, dag in dagbag.dags.items():
        assert dag.tags, f"{dag_id}: no tags"
        assert dag.default_args.get("owner") not in (None, "airflow"), f"{dag_id}: no owner"
        assert dag.default_args.get("retries", 0) >= 1, f"{dag_id}: no retries"
        assert dag.max_active_runs == 1, f"{dag_id}: concurrent runs would race on a partition"


@pytest.mark.parametrize("task_id", ["dbt_run", "dbt_test"])
def test_daily_orders_tasks_read_the_partition_from_the_run(dagbag, task_id: str) -> None:
    dag = dagbag.dags["daily_orders"]
    task = dag.get_task(task_id)

    command = task.bash_command
    assert "data_interval_start" in command
    assert "data_interval_end" in command
    assert "--full-refresh" not in command
    assert "--select tag:daily" in command


def test_daily_orders_runs_before_it_tests(dagbag) -> None:
    dag = dagbag.dags["daily_orders"]

    assert dag.get_task("dbt_test").upstream_task_ids == {"dbt_run"}
    assert dag.catchup is False


def test_every_dag_run_gets_a_data_interval_with_length(dagbag) -> None:
    # A cron string in Airflow 3 gives start == end: an empty window, a green run, no rows.
    run_after = pendulum.datetime(2026, 1, 2, 1, tz="UTC")
    for dag_id, dag in dagbag.dags.items():
        interval = dag.timetable.infer_manual_data_interval(run_after=run_after)
        assert interval.end > interval.start, f"{dag_id}: zero-length data interval"
