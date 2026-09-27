"""DAG structure checks that run without Airflow installed (read with ast)."""

import ast
from pathlib import Path

DAGS = sorted(Path(__file__).resolve().parent.parent.joinpath("dags").glob("*.py"))


def dag_kwargs(tree):
    for node in ast.walk(tree):
        if isinstance(node, ast.FunctionDef):
            for dec in node.decorator_list:
                if isinstance(dec, ast.Call) and getattr(dec.func, "id", "") == "dag":
                    return {k.arg: k.value for k in dec.keywords}
    return None


def test_there_are_dags():
    assert DAGS, "no DAG files found under dags/"
    print(f"checked {len(DAGS)} DAG files")


def test_every_dag_has_owner_retries_tags_and_no_catchup():
    for path in DAGS:
        tree = ast.parse(path.read_text())
        kw = dag_kwargs(tree)
        assert kw is not None, f"{path.name}: no @dag"
        for key in ("dag_id", "schedule", "start_date", "tags", "default_args", "dagrun_timeout"):
            assert key in kw, f"{path.name}: @dag has no {key}"
        assert isinstance(kw.get("catchup"), ast.Constant) and kw["catchup"].value is False, (
            f"{path.name}: catchup must be False; backfill explicitly"
        )
        d = kw["default_args"]
        defaults = {k.value: v for k, v in zip(d.keys, d.values) if isinstance(v, ast.Constant)}
        assert defaults.get("owner") and defaults["owner"].value, f"{path.name}: no owner"
        assert "retries" in defaults and defaults["retries"].value >= 1, f"{path.name}: no retries"


def test_dag_files_are_import_safe():
    banned = ("Variable.get", "Connection.get", "datetime.now", "pendulum.now", "psycopg")
    for path in DAGS:
        tree = ast.parse(path.read_text())
        for node in tree.body:
            if isinstance(node, (ast.FunctionDef, ast.ClassDef)):
                continue
            src = ast.unparse(node)
            for b in banned:
                assert b not in src, f"{path.name}: {b} at module level"


def test_dbt_tasks_take_the_run_window():
    for path in DAGS:
        text = path.read_text()
        if "dbt" in text:
            assert "data_interval_start" in text and "data_interval_end" in text, (
                f"{path.name}: dbt tasks must take the window from the run's data interval"
            )
