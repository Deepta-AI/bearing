"""dbt layout rules: prefixes, no select *, one-way layers, tests on marts."""

import re
from pathlib import Path

import yaml

MODELS = Path(__file__).resolve().parent.parent / "dbt" / "models"
PREFIX = {"staging": "stg_", "intermediate": "int_", "marts": ("dim_", "fct_")}


def sql_models():
    return sorted(MODELS.rglob("*.sql"))


def yml_models(layer):
    out = {}
    for path in (MODELS / layer).glob("_*.yml"):
        for m in (yaml.safe_load(path.read_text()) or {}).get("models", []) or []:
            out[m["name"]] = m
    return out


def test_there_are_models():
    models = sql_models()
    assert models, "no dbt models found"
    print(f"checked {len(models)} models")


def test_prefixes_match_layer():
    for path in sql_models():
        layer = path.parent.name
        assert path.stem.startswith(PREFIX[layer]), f"{path.name} in {layer}"


def test_no_select_star():
    for path in sql_models():
        assert not re.search(r"select\s+\*", path.read_text(), re.I), f"select * in {path.name}"


def test_layers_point_one_way():
    for path in sql_models():
        text = path.read_text()
        layer = path.parent.name
        if layer != "staging":
            assert "source(" not in text, f"{path.name}: only staging reads sources"
        if layer == "intermediate":
            for ref in re.findall(r"ref\('([a-z_]+)'\)", text):
                assert ref.startswith("stg_"), f"{path.name}: intermediate reads {ref}"


def test_every_model_is_documented_and_marts_are_tested():
    for layer in PREFIX:
        documented = yml_models(layer)
        for path in (MODELS / layer).glob("*.sql"):
            assert path.stem in documented, f"{path.name}: no yml entry"
            if layer == "marts":
                cols = documented[path.stem].get("columns") or []
                assert any(c.get("data_tests") for c in cols), f"{path.name}: no data_tests"
