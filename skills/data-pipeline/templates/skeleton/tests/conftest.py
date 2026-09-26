"""Shared fixtures: the DagBag, the dbt project and the repository root."""

from __future__ import annotations

from pathlib import Path

import pytest
import yaml

ROOT = Path(__file__).resolve().parent.parent
DAGS = ROOT / "dags"
DBT = ROOT / "dbt"


@pytest.fixture(scope="session")
def dagbag():
    """Every DAG under dags/, imported once per session."""
    try:
        from airflow.dag_processing.dagbag import DagBag
    except ImportError:  # Airflow before 3.3 keeps it under models
        from airflow.models.dagbag import DagBag

    return DagBag(dag_folder=str(DAGS))


@pytest.fixture(scope="session")
def dbt_project() -> dict:
    """The parsed dbt_project.yml."""
    with (DBT / "dbt_project.yml").open(encoding="utf-8") as handle:
        return yaml.safe_load(handle)


@pytest.fixture(scope="session")
def model_files() -> list[Path]:
    """Every model SQL file, staging through marts."""
    files = sorted((DBT / "models").rglob("*.sql"))
    assert files, "no model files under dbt/models"
    return files
