"""Import every DAG file and fail on any import error. Run by `make dag-test`.

A DAG that fails to import never runs and Airflow only shows it in the UI,
so this is the gate that catches it before merge. Prints the count of files
and DAGs; zero files is a failure.
"""

from __future__ import annotations

import sys
from pathlib import Path

DAGS = Path(__file__).resolve().parent.parent / "dags"


def main() -> int:
    """Return the exit status: 0 when every DAG file imports cleanly."""
    # Imported here so the module is cheap to import and AIRFLOW_HOME is set by the Makefile.
    try:
        from airflow.dag_processing.dagbag import DagBag
    except ImportError:  # Airflow before 3.3 keeps it under models
        from airflow.models.dagbag import DagBag

    files = sorted(p for p in DAGS.rglob("*.py") if not p.name.startswith("_"))
    if not files:
        print(f"dag-test: 0 DAG files under {DAGS}, nothing checked", file=sys.stderr)
        return 1
    bag = DagBag(dag_folder=str(DAGS))
    for path, error in sorted(bag.import_errors.items()):
        print(f"import error in {path}:\n{error}", file=sys.stderr)
    if bag.import_errors:
        print(
            f"dag-test: {len(bag.import_errors)} of {len(files)} DAG files failed", file=sys.stderr
        )
        return 1
    print(f"dag-test: {len(files)} DAG files checked, {len(bag.dags)} DAGs")
    return 0


if __name__ == "__main__":
    sys.exit(main())
