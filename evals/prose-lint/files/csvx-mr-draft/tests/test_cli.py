import pytest

from csvx.cli import NO_MATCH, main
from tests.conftest import read


def test_min_rating_flag(reviews, tmp_path, capsys):
    dest = tmp_path / "out.csv"
    assert main([str(reviews), str(dest), "--min-rating", "excellent"]) == 0
    assert [r["id"] for r in read(dest)] == ["3"]
    assert "1 rows written" in capsys.readouterr().out


def test_no_match_message(tmp_path, capsys):
    src = tmp_path / "empty.csv"
    src.write_text("id,product,rating\n", encoding="utf-8")
    main([str(src), str(tmp_path / "out.csv")])
    assert capsys.readouterr().out.strip() == NO_MATCH
    assert NO_MATCH == "0 rows matched {{EMDASH}} nothing written"


def test_unknown_rating_is_rejected(reviews, tmp_path):
    with pytest.raises(SystemExit):
        main([str(reviews), str(tmp_path / "out.csv"), "--min-rating", "great"])
