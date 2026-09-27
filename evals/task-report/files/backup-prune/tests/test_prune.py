import pytest

from backupctl.prune import prune_local, select_for_deletion

SEPT = [f"db-{d:02d}-09-2026.tar.gz" for d in range(1, 6)]


def test_keeps_the_newest():
    assert select_for_deletion(SEPT, 3) == ["db-01-09-2026.tar.gz", "db-02-09-2026.tar.gz"]


def test_keep_more_than_exist_deletes_nothing():
    assert select_for_deletion(SEPT, 10) == []


def test_keep_must_be_positive():
    with pytest.raises(ValueError):
        select_for_deletion(SEPT, 0)


def test_prune_local_leaves_other_files(tmp_path):
    for n in SEPT + ["notes.txt"]:
        (tmp_path / n).write_text("x")
    deleted = prune_local(tmp_path, 2)
    assert len(deleted) == 3
    left = sorted(p.name for p in tmp_path.iterdir())
    assert left == ["db-04-09-2026.tar.gz", "db-05-09-2026.tar.gz", "notes.txt"]
