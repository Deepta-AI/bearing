"""The dbt project keeps its layer rules: layers, naming, no select *, tested marts."""

from __future__ import annotations

import re
from pathlib import Path

import yaml

PREFIX = {"staging": "stg_", "intermediate": "int_", "marts": ("dim_", "fct_")}
SELECT_STAR = re.compile(r"\bselect\s+\*", re.IGNORECASE)
COMMENT = re.compile(r"--[^\n]*|/\*.*?\*/|\{#.*?#\}", re.DOTALL)


def sql_without_comments(path: Path) -> str:
    """The model's SQL with line, block and jinja comments removed."""
    return COMMENT.sub("", path.read_text(encoding="utf-8"))


def test_project_names_the_three_layers(dbt_project: dict) -> None:
    layers = dbt_project["models"]["pipeline"]
    assert {"staging", "intermediate", "marts"} <= set(layers)
    assert layers["marts"]["+materialized"] == "table"


def test_every_model_sits_in_a_layer_with_the_right_prefix(model_files: list[Path]) -> None:
    for path in model_files:
        layer = path.parent.name
        assert layer in PREFIX, f"{path}: not under staging, intermediate or marts"
        assert path.name.startswith(PREFIX[layer]), f"{path}: wrong prefix for {layer}"


def test_no_model_selects_star(model_files: list[Path]) -> None:
    offenders = [p for p in model_files if SELECT_STAR.search(sql_without_comments(p))]
    assert offenders == [], f"select * in {offenders}"


def test_incremental_models_declare_a_unique_key(model_files: list[Path]) -> None:
    for path in model_files:
        text = path.read_text(encoding="utf-8")
        if "materialized='incremental'" in text:
            assert "unique_key=" in text, f"{path}: incremental without unique_key"
            assert 'var("start_date")' in text, f"{path}: incremental without a partition window"


def test_every_mart_has_tests(model_files: list[Path]) -> None:
    marts = [p for p in model_files if p.parent.name == "marts"]
    assert marts
    documented: dict[str, dict] = {}
    for yml in marts[0].parent.glob("*.yml"):
        with yml.open(encoding="utf-8") as handle:
            for model in yaml.safe_load(handle).get("models", []):
                documented[model["name"]] = model
    for path in marts:
        model = documented.get(path.stem)
        assert model is not None, f"{path.stem}: no yml entry under models/marts"
        tests = [t for c in model.get("columns", []) for t in c.get("data_tests", [])]
        assert tests, f"{path.stem}: no data_tests"
