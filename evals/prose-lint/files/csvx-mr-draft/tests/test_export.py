from csvx.export import export
from tests.conftest import read


def test_copies_every_row_by_default(reviews, tmp_path):
    dest = tmp_path / "out.csv"
    assert export(reviews, dest) == 4
    assert len(read(dest)) == 4


def test_keeps_only_named_columns(reviews, tmp_path):
    dest = tmp_path / "out.csv"
    export(reviews, dest, columns=["id", "rating"])
    assert list(read(dest)[0].keys()) == ["id", "rating"]


def test_rerun_overwrites_dest(reviews, tmp_path):
    dest = tmp_path / "out.csv"
    export(reviews, dest)
    export(reviews, dest)
    assert len(read(dest)) == 4


def test_min_rating_keeps_that_rating_and_above(reviews, tmp_path):
    dest = tmp_path / "out.csv"
    assert export(reviews, dest, min_rating="good") == 2
    assert {r["rating"] for r in read(dest)} == {"good", "excellent"}


def test_small_batches_write_every_row(reviews, tmp_path):
    dest = tmp_path / "out.csv"
    assert export(reviews, dest, batch_size=1) == 4
    assert [r["id"] for r in read(dest)] == ["1", "2", "3", "4"]
