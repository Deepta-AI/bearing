import pytest

from refunds.reasons import describe


def test_known_reason():
    assert describe("LATE") == "Delivered after the promised date"


def test_unknown_reason():
    with pytest.raises(ValueError):
        describe("NOPE")
