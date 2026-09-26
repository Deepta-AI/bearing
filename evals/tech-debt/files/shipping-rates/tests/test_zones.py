import pytest

from rates.zones import resolve_zone


def test_metro_is_zone_a():
    assert resolve_zone("110001") == "A"
    assert resolve_zone(560001) == "A"


def test_regional_is_zone_b():
    assert resolve_zone("302001") == "B"


def test_rejects_malformed():
    with pytest.raises(ValueError):
        resolve_zone("1100")
